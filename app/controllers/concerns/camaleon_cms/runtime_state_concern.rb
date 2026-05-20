require 'net/http'
require 'tempfile'

# rubocop:disable Metrics/ModuleLength, Naming/MethodParameterName, Style/GlobalVars

module CamaleonCms
  module RuntimeStateConcern
    extend ActiveSupport::Concern
    include CamaleonCms::RuntimeShortcodeThemeConcern
    include CamaleonCms::RuntimeHtmlContentConcern
    include CamaleonCms::RuntimeAdminMenuConcern

    delegate :tag, :content_tag, :safe_join, :image_tag, :link_to, :sanitize, to: :helpers

    UNSAFE_EVENT_PATTERNS = %w[
      onabort onafter onbefore onblur oncanplay onchange onclick oncontextmenu oncopy oncuechange oncut ondblclick
      ondrag ondrop ondurationchange onended onerror onfocus onhashchange oninvalid oninput onkey onload onmessage
      onmouse ononline onoffline onpagehide onpageshow onpage onpaste onpause onplay onpopstate onprogress
      onpropertychange onratechange onreadystatechange onreset onresize onscroll onsearch onseek onselect onshow
      onstalled onstorage onsuspend ontimeupdate ontoggle onunloadonsubmit onvolumechange onwaiting onwheel
    ].map { |pattern| /#{pattern}\w*\s*=/i }.freeze

    SUSPICIOUS_PATTERNS = (UNSAFE_EVENT_PATTERNS + [
      /<script[\s>]/i,
      /javascript:/i,
      /<iframe[\s>]/i,
      /<object[\s>]/i,
      /<embed[\s>]/i,
      /<base[\s>]/i,
      /data:/i
    ]).freeze

    def cama_captcha_build(len = 5)
      img = MiniMagick::Image.open(resolve_captcha_file("captcha_#{rand(12)}.jpg"))
      text = cama_rand_str(len)
      session[:cama_captcha] = [] if session[:cama_captcha].blank?
      session[:cama_captcha] << text
      img.combine_options do |c|
        c.gravity('Center')
        c.fill('#FFFFFF')
        c.draw("text 0,5 #{text}")
        c.font(resolve_captcha_file('bumpyroad.ttf'))
        c.pointsize('30')
      end
    end

    def upload_file(uploaded_io, settings = {})
      cached_name = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.original_filename : nil
      return { error: 'File is empty', file: nil, size: nil } if uploaded_io.blank?

      if uploaded_io.is_a?(String) && uploaded_io.match(%r{^https?://}).present?
        tmp = cama_tmp_upload(uploaded_io)
        return tmp if tmp[:error].present?

        settings[:remove_source] = true
        uploaded_io = tmp[:file_path]
      end
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      if settings[:dimension].present?
        uploaded_io = File.open(cama_resize_upload(uploaded_io.path, settings[:dimension]))
      end

      return { error: 'Potentially malicious content found!' } if file_content_unsafe?(uploaded_io)

      settings[:uploaded_io] = uploaded_io
      settings = settings.to_h.symbolize_keys
      settings = {
        folder: '',
        maximum: current_site.get_option('filesystem_max_size', 100).to_f.megabytes,
        formats: '*',
        generate_thumb: true,
        temporal_time: 0,
        filename: begin
          cached_name || uploaded_io.original_filename
        rescue StandardError
          uploaded_io.path.split('/').last
        end.cama_fix_filename,
        file_size: File.size(uploaded_io.to_io),
        remove_source: false,
        same_name: false,
        versions: '',
        thumb_size: nil
      }.merge!(settings)
      hooks_run('before_upload', settings)

      return { error: 'Invalid file path' } unless cama_uploader.valid_folder_path?(settings[:folder])

      err = validate_file_format_or_error(uploaded_io.path, settings[:formats])
      return err if err

      if settings[:maximum] < settings[:file_size]
        max_size = helpers.number_to_human_size(settings[:maximum])
        return { error: "#{I18n.t('camaleon_cms.common.file_size_exceeded',
                                  default: 'File size exceeded')} (#{max_size})" }
      end
      key = File.join(settings[:folder], settings[:filename]).to_s.cama_fix_slash
      res = cama_uploader.add_file(settings[:uploaded_io], key, { same_name: settings[:same_name] })

      if res['file_type'] == 'image'
        settings[:versions].to_s.delete(' ').split(',').each do |v|
          version_path = cama_resize_upload(settings[:uploaded_io].path, v, { replace: false })
          cama_uploader.add_file(version_path, cama_uploader.version_path(res['key'], v), is_thumb: true,
                                                                                          same_name: true)
          FileUtils.rm_f(version_path)
        end
      end

      if settings[:generate_thumb] && res['thumb'].present?
        cama_uploader_generate_thumbnail(uploaded_io.path, res['key'], settings[:thumb_size],
                                         settings[:remove_source])
      end
      FileUtils.rm_f(uploaded_io.path) if settings[:remove_source] && File.exist?(uploaded_io.path)

      hooks_run('after_upload', settings)
      CamaleonCmsUploader.delete_block.call(settings, cama_uploader, key) if settings[:temporal_time] > 0

      res
    end

    def cama_uploader_generate_thumbnail(uploaded_io, key, thumb_size = nil, remove_source = false)
      w = thumb_size.present? ? thumb_size.split('x')[0] : cama_uploader.thumb[:w]
      h = thumb_size.present? ? thumb_size.split('x')[1] : cama_uploader.thumb[:h]
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      path_thumb = cama_resize_and_crop(uploaded_io.path, w, h)
      thumb = cama_uploader.add_file(path_thumb, cama_uploader.version_path(key).sub('.svg', '.jpg'), is_thumb: true,
                                                                                                      same_name: true)
      FileUtils.rm_f(path_thumb) if remove_source
      thumb
    end

    def uploader_verify_name(file_path)
      dir = File.dirname(file_path)
      filename = File.basename(file_path).to_s.cama_fix_filename
      files = Dir.entries(dir)
      if files.include?(filename)
        i = 1
        _filename = filename
        while files.include?(_filename)
          _filename = "#{File.basename(filename, File.extname(filename))}_#{i}#{File.extname(filename)}"
          i += 1
        end
        filename = _filename
      end
      "#{File.dirname(file_path)}/#{filename}"
    end

    def cama_file_path_to_url(file_path)
      file_path.sub(Rails.public_path.to_s, begin
        root_url
      rescue StandardError
        cama_root_url
      end)
    end

    def cama_url_to_file_path(url)
      File.join(Rails.public_path, URI(url.to_s).path)
    end

    def cama_crop_image(file_path, w = nil, h = nil, w_offset = 0, h_offset = 0, resize = false, replace = true)
      force = w.present? && h.present? && !w.include?('?') && !h.include?('?') ? '!' : ''
      img = MiniMagick::Image.open(file_path)
      w = clamp_to_image_dimension(w, img[:width])
      h = clamp_to_image_dimension(h, img[:height])
      data = { img: img, w: w, h: h, w_offset: w_offset, h_offset: h_offset, resize: resize, replace: replace }
      hooks_run('before_crop_image', data)
      data[:img].combine_options do |i|
        i.resize("#{w.presence}x#{h.presence}#{force}") if data[:resize]
        i.crop "#{w.presence}x#{h.presence}+#{w_offset}+#{h_offset}#{force}" unless data[:resize]
      end

      ext = File.extname(file_path)
      res = data[:replace] ? file_path : file_path.gsub(ext, "_crop#{ext}")
      data[:img].write res
      res
    end

    def cama_resize_and_crop(file, w, h, settings = {})
      settings = { gravity: :north_east, overwrite: true, output_name: +'' }.merge!(settings)
      img = MiniMagick::Image.open(file)
      if file.end_with? '.svg'
        img.format 'jpg'
        file.sub! '.svg', '.jpg'
        settings[:output_name]&.sub!('.svg', '.jpg')
      end
      w = clamp_to_image_dimension(w, img[:width])
      h = clamp_to_image_dimension(h, img[:height])
      w_original = img[:width].to_f
      h_original = img[:height].to_f
      w = w.to_i if w.present?
      h = h.to_i if h.present?

      if w_original * h < h_original * w
        op_resize = "#{w.to_i}x"
        w_result = w
        h_result = (h_original * w / w_original)
      else
        op_resize = "x#{h.to_i}"
        w_result = (w_original * h / h_original)
        h_result = h
      end

      w_offset, h_offset = cama_crop_offsets_by_gravity(settings[:gravity], [w_result, h_result], [w, h])
      data = { img: img, w: w, h: h, w_offset: w_offset, h_offset: h_offset, op_resize: op_resize, settings: settings }
      hooks_run('before_resize_crop', data)
      data[:img].combine_options do |i|
        i.resize(data[:op_resize])
        i.gravity(settings[:gravity])
        i.crop "#{data[:w].to_i}x#{data[:h].to_i}+#{data[:w_offset]}+#{data[:h_offset]}!"
      end

      if settings[:overwrite]
        data[:img].write(file.sub('.svg', '.jpg'))
      elsif settings[:output_name].present?
        data[:img].write(file = File.join(File.dirname(file), settings[:output_name]).to_s)
      else
        data[:img].write(file = uploader_verify_name(File.join(File.dirname(file),
                                                               "crop_#{File.basename(file.sub('.svg', '.jpg'))}")))
      end
      file
    end

    def cama_tmp_upload(uploaded_io, args = {})
      tmp_path = args[:path] || File.join(Rails.public_path, 'tmp', current_site.id.to_s).to_s
      FileUtils.mkdir_p(tmp_path)
      saved = false
      downloaded_tmp_file = nil
      if uploaded_io.is_a?(String) && uploaded_io.start_with?('data:')
        _tmp_name = args[:name]
        return { error: I18n.t('camaleon_cms.admin.media.name_required').to_s } if params[:name].blank?

        err = validate_file_format_or_error(_tmp_name, args[:formats])
        return err if err

        path = uploader_verify_name(File.join(tmp_path, _tmp_name))
        File.open(path, 'wb') { |f| f.write(Base64.decode64(uploaded_io.split(';base64,').last)) }
        uploaded_io = File.open(path)
        saved = true
      elsif uploaded_io.is_a?(String) && uploaded_io.start_with?('http://', 'https://')
        err = validate_file_format_or_error(uploaded_io, args[:formats])
        return err if err

        if uploaded_io.include?(current_site.the_url(locale: nil))
          uploaded_io = File.join(Rails.public_path, uploaded_io.sub(current_site.the_url(locale: nil), '')).to_s
        else
          remote_file = cama_download_remote_file(uploaded_io)
          return remote_file if remote_file[:error].present?

          downloaded_tmp_file = remote_file[:file]
          uploaded_io = downloaded_tmp_file
        end
        _tmp_name = if uploaded_io.is_a?(String)
                      uploaded_io.split('/').last.split('?').first
                    else
                      uploaded_io.path.split('/').last
                    end
        args[:name] = args[:name] || _tmp_name
      end
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      err = validate_file_format_or_error(_tmp_name || uploaded_io.path, args[:formats])
      return err if err

      actual_size = begin
        uploaded_io.size
      rescue StandardError
        File.size(uploaded_io)
      end
      if args[:maximum].present? && args[:maximum] < actual_size
        max_size = helpers.number_to_human_size(args[:maximum])
        return { error: "#{I18n.t('camaleon_cms.common.file_size_exceeded',
                                  default: 'File size exceeded')} (#{max_size})" }
      end

      name = args[:name] || uploaded_io&.original_filename || uploaded_io.path.split('/').last
      name = "#{File.basename(name, File.extname(name)).parameterize}#{File.extname(name)}"
      path ||= uploader_verify_name(File.join(tmp_path, name))
      File.open(path, 'wb') { |f| f.write(uploaded_io.read) } unless saved
      path = cama_resize_upload(path, args[:dimension]) if args[:dimension].present?
      { file_path: path, error: nil }
    ensure
      downloaded_tmp_file&.close!
    end

    def cama_resize_upload(image_path, dimension, args = {})
      if cama_uploader.class.validate_file_format(image_path, 'image') && dimension.present?
        dim_parts = dimension.split('x')
        r = { file: image_path, w: dim_parts[0], h: dim_parts[1], w_offset: 0, h_offset: 0,
              resize: !dim_parts[2] || dim_parts[2] == 'resize',
              replace: true, gravity: :north_east }.merge!(args)
        hooks_run('on_uploader_resize', r)
        image_path = if r[:w].present? && r[:h].present?
                       cama_resize_and_crop(r[:file], r[:w], r[:h], { overwrite: r[:replace], gravity: r[:gravity] })
                     else
                       cama_crop_image(r[:file], r[:w], r[:h], r[:w_offset], r[:h_offset], r[:resize], r[:replace])
                     end
      end
      image_path
    end

    def cama_uploader
      @cama_uploader ||= lambda {
        thumb = current_site.get_option('filesystem_thumb_size', '100x100').split('x')
        args = {
          server: current_site.get_option('filesystem_type', 'local').downcase,
          thumb: { w: thumb[0], h: thumb[1] },
          aws_settings: {
            region: current_site.get_option('filesystem_region', 'us-west-2'),
            access_key: current_site.get_option('filesystem_s3_access_key'),
            secret_key: current_site.get_option('filesystem_s3_secret_key'),
            bucket: current_site.get_option('filesystem_s3_bucket_name'),
            cloud_front: current_site.get_option('filesystem_s3_cloudfront'),
            aws_file_upload_settings: ->(settings) { settings },
            aws_file_read_settings: ->(data, _s3_file) { data }
          },
          custom_uploader: nil
        }
        hooks_run('on_uploader', args)
        return args[:custom_uploader] if args[:custom_uploader].present?

        base_args = { current_site: current_site, thumb: args[:thumb] }
        case args[:server]
        when 's3', 'aws'
          CamaleonCmsAwsUploader.new(base_args.merge(aws_settings: args[:aws_settings]), self)
        else
          CamaleonCmsLocalUploader.new(base_args, self)
        end
      }.call
    end

    def slugify(val)
      val.to_s.downcase.strip.tr(' ', '-').gsub(/[^\w-]/, '')
    end

    def slugify_folder(val)
      split_folder = val.split('/')
      split_folder[-1] = slugify(split_folder[-1])
      split_folder.join('/')
    end

    private

    def resolve_captcha_file(filename)
      base_dir = $camaleon_engine_dir.presence || Rails.root.to_s
      File.join(base_dir, 'lib', 'captcha', filename)
    end

    def cama_rand_str(len = 6)
      alphabets = [('A'..'Z').to_a].flatten!
      alphanumerics = [('A'..'Z').to_a, ('1'..'9').to_a].flatten!
      str = alphabets[rand(alphabets.size)]
      (len.to_i - 1).times do
        str << alphanumerics[rand(alphanumerics.size)]
      end
      str
    end

    def cama_download_remote_file(url)
      validation_result = UserUrlValidator.validate(url)
      return { error: validation_result.join(', ') } if validation_result.is_a?(Array)

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request(Net::HTTP::Get.new(uri.request_uri.presence || '/'))
      end

      return { error: 'Redirects are not allowed for remote uploads.' } if response.is_a?(Net::HTTPRedirection)
      unless response.is_a?(Net::HTTPSuccess)
        return { error: "Unable to download remote file (HTTP #{response.code})." }
      end

      max_bytes = current_site.get_option('filesystem_max_size', 100).to_f.megabytes
      body = response.body
      if body.bytesize > max_bytes
        return { error: "Remote file too large (max #{ActiveSupport::NumberHelper.number_to_human_size(max_bytes)})." }
      end

      ext = File.extname(uri.path.to_s)
      tempfile = Tempfile.new(['cama-upload-url', ext], binmode: true)
      tempfile.write(body)
      tempfile.rewind
      { file: tempfile, error: nil }
    rescue StandardError => e
      { error: "Unable to download remote file: #{ERB::Util.html_escape(e.message)}" }
    end

    def file_content_unsafe?(uploaded_io)
      file = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.tempfile : uploaded_io
      file_content_unsafe = nil

      file.set_encoding(Encoding::BINARY) if file.respond_to?(:binmode) && file.respond_to?(:set_encoding)

      file_content = file.read
      file.rewind if file.respond_to?(:rewind)
      SUSPICIOUS_PATTERNS.each do |pattern|
        if file_content&.match?(pattern)
          Rails.logger.info { "Potentially malicious content found: #{pattern.inspect}" }
          break file_content_unsafe = pattern.inspect
        end
      end

      file_content_unsafe
    end

    def cama_crop_offsets_by_gravity(gravity, original_dimensions, cropped_dimensions)
      original_width, original_height = original_dimensions
      cropped_width, cropped_height = cropped_dimensions

      vertical_offset = case gravity
                        when :north_west, :north, :north_east then 0
                        when :center, :east, :west then [((original_height - cropped_height) / 2.0).to_i, 0].max
                        when :south_west, :south, :south_east then (original_height - cropped_height).to_i
                        end

      horizontal_offset = case gravity
                          when :north_west, :west, :south_west then 0
                          when :center, :north, :south then [((original_width - cropped_width) / 2.0).to_i, 0].max
                          when :north_east, :east, :south_east then (original_width - cropped_width).to_i
                          end

      [horizontal_offset, vertical_offset]
    end

    def clamp_to_image_dimension(value, img_size)
      return value unless value.present? && value.to_s.include?('?')

      img_size.to_f > value.sub('?', '').to_i ? value.sub('?', '') : img_size
    end

    def validate_file_format_or_error(file, formats)
      return if cama_uploader.class.validate_file_format(file, formats)

      { error: "#{I18n.t('camaleon_cms.common.file_format_error')} (#{formats})" }
    end
  end
end

# rubocop:enable Metrics/ModuleLength, Naming/MethodParameterName, Style/GlobalVars
