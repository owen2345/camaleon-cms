# frozen_string_literal: true

require 'net/http'
require 'tempfile'

module CamaleonCms
  # Staging and persistence pipeline shared by the two uploader entry points:
  # CamaleonCms::RuntimeUploaderConcern (controllers) and CamaleonCms::UploaderHelper
  # (views, ActiveJobs, standalone objects). Both include this module, so a fix to
  # upload staging or persistence cannot land in one entry point and not the other.
  #
  # Nothing here may read request state such as `params`: UploaderHelper is documented
  # in config/initializers/custom_initializers.rb as includable from an ActiveJob, where
  # no request exists. Context differences go through the message seam at the bottom.
  module UploaderPipeline
    # upload a file into server
    # settings:
    #   folder: Directory where the file will be saved (default: "")
    #     sample: temporal => will save in /rails_path/public/temporal
    #   generate_thumb: true, # generate thumb image if this is image format (default true)
    #   maximum: maximum bytes permitted to upload (default: 1000MG)
    #   dimension: dimension for the image (sample: 30x30 | x30 | 30x | 300x300?)
    #   formats: extensions permitted, sample: jpg,png,... or generic: images | videos | audios | documents (default *)
    #   remove_source: Boolean (delete source file after saved if this is true, default false)
    #   same_name: Boolean (save the file with the same name if defined true, else search for a non used name)
    #   versions: (String) Create additional multiple versions of the image uploaded,
    #     sample: '300x300,505x350' ==> Will create two extra images with these dimensions
    #     sample "test.png", versions: '200x200,450x450' will generate: thumb/test-png_200x200.png, test-png_450x450.png
    #   thumb_size: String (redefine the dimensions of the thumbnail, sample: '100x100' ==> only for images)
    #   temporal_time: if great than 0 seconds, then this file will expire (removed) in that time (default: 0)
    #     To manage jobs, please check https://edgeguides.rubyonrails.org/active_job_basics.html
    #     Note: if you are using temporal_time, you will need to copy the file to another directory later
    # sample: upload_file(params[:my_file], {formats: "images", folder: "temporal"})
    # sample: upload_file(params[:my_file], {formats: "jpg,png,gif,mp3,mp4",
    #           temporal_time: 10.minutes, maximum: 10.megabytes})
    def upload_file(uploaded_io, settings = {})
      cached_name = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.original_filename : nil
      return { error: 'File is empty', file: nil, size: nil } if uploaded_io.blank?

      if uploaded_io.is_a?(String) && uploaded_io.match(%r{^https?://}).present? # download url file
        tmp = cama_tmp_upload(uploaded_io)
        return tmp if tmp[:error].present?

        settings[:remove_source] = true
        uploaded_io = tmp[:file_path]
      end
      if uploaded_io.is_a?(String)
        expanded = cama_canonical_upload_path(uploaded_io)
        return { error: 'Invalid file path' } unless expanded

        uploaded_io = expanded
      end
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      if settings[:dimension].present?
        uploaded_io = File.open(cama_resize_upload(uploaded_io.path, settings[:dimension]))
      end

      if file_content_unsafe?(uploaded_io)
        return cama_upload_failure({ error: 'Potentially malicious content found!' }, uploaded_io, settings)
      end

      settings = settings.to_h.deep_symbolize_keys
      settings[:uploaded_io] = uploaded_io
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
      settings[:formats] = '*' if settings[:formats].nil?
      settings[:folder] = '' if settings[:folder].nil? # e.g. crop_url passes no folder
      hooks_run('before_upload', settings)

      # guard against path traversal
      unless cama_uploader.valid_folder_path?(settings[:folder])
        return cama_upload_failure({ error: 'Invalid file path' }, uploaded_io, settings)
      end

      # formats validations
      err = validate_file_format_or_error(uploaded_io.path, settings[:formats])
      return cama_upload_failure(err, uploaded_io, settings) if err

      # file size validations
      err = cama_size_limit_error(settings[:file_size], settings[:maximum])
      return cama_upload_failure(err, uploaded_io, settings) if err

      # save file
      key = File.join(settings[:folder], settings[:filename]).to_s.cama_fix_slash
      res = cama_uploader.add_file(settings[:uploaded_io], key, { same_name: settings[:same_name] })

      # generate image versions
      if res['file_type'] == 'image'
        settings[:versions].to_s.delete(' ').split(',').each do |v|
          version_path = cama_resize_upload(settings[:uploaded_io].path, v, { replace: false })
          cama_uploader.add_file(version_path, cama_uploader.version_path(res['key'], v), is_thumb: true,
                                                                                          same_name: true)
          FileUtils.rm_f(version_path)
        end
      end

      # generate thumb
      if settings[:generate_thumb] && res['thumb'].present?
        cama_uploader_generate_thumbnail(uploaded_io.path, res['key'], settings[:thumb_size],
                                         settings[:remove_source])
      end
      FileUtils.rm_f(uploaded_io.path) if settings[:remove_source] && File.exist?(uploaded_io.path)

      hooks_run('after_upload', settings)

      # temporal file upload (always put as local for temporal files)
      CamaleonCmsUploader.delete_block.call(settings, cama_uploader, key) if settings[:temporal_time] > 0

      res
    end

    # upload tmp file
    # support for url and local path
    # sample:
    # cama_tmp_upload('https://camaleon.website/media/132/logo2.png')  ==> /var/rails/my_project/public/tmp/1/logo2.png
    # cama_tmp_upload('/var/www/media/132/logo 2.png')  ==> /var/rails/my_project/public/tmp/1/logo-2.png
    # accept args:
    #   name: to indicate the name to use,
    #     sample: cama_tmp_upload('/var/www/media/132/logo 2.png', {name: 'owen.png', formats: 'images'})
    #   formats: extensions permitted, sample: jpg,png,... or generic: images | videos | audios | documents (default *)
    #   dimension: 20x30
    # return: {file_path, error}
    def cama_tmp_upload(uploaded_io, args = {})
      tmp_path = args[:path] || File.join(Rails.public_path, 'tmp', current_site.id.to_s).to_s
      FileUtils.mkdir_p(tmp_path)
      # Default to the site limit so the size guard below actually applies: callers
      # such as crop/crop_url pass no :maximum, which left it dead code.
      args[:maximum] ||= current_site.get_option('filesystem_max_size', 100).to_f.megabytes
      saved = false
      downloaded_tmp_file = nil
      staged_path = nil
      if uploaded_io.is_a?(String) && uploaded_io.start_with?('data:') # create tmp file using base64 format
        path, err = cama_stage_data_uri(uploaded_io, args, tmp_path)
        return err if err

        staged_path = path
        _tmp_name = File.basename(args[:name].to_s)
        uploaded_io = File.open(path)
        saved = true
      elsif uploaded_io.is_a?(String) && uploaded_io.start_with?('http://', 'https://')
        err = validate_file_format_or_error(uploaded_io, args[:formats])
        return err if err

        if same_site_url?(uploaded_io, current_site)
          uploaded_io = File.join(Rails.public_path, site_url_path(uploaded_io, current_site)).to_s
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
      if uploaded_io.is_a?(String)
        expanded = cama_canonical_upload_path(uploaded_io)
        return { error: 'Invalid file path' } unless expanded

        uploaded_io = expanded
      end
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      err = validate_file_format_or_error(_tmp_name || uploaded_io.path, args[:formats])
      return err if err

      actual_size = begin
        uploaded_io.size
      rescue StandardError
        File.size(uploaded_io)
      end
      err = cama_size_limit_error(actual_size, args[:maximum])
      return err if err

      name = args[:name] || uploaded_io&.original_filename || uploaded_io.path.split('/').last
      name = "#{File.basename(name, File.extname(name)).parameterize}#{File.extname(name)}"
      path ||= uploader_verify_name(File.join(tmp_path, name))
      unless saved
        # Same rule as the data: branch above -- read, scan, and only then write, so
        # a remote or same-site source cannot land unscanned in public/tmp.
        content = uploaded_io.read
        return { error: 'Potentially malicious content found!' } if content_unsafe?(content, filename: name)

        File.open(path, 'wb') { |f| f.write(content) }
        staged_path = path
      end
      path = cama_resize_upload(path, args[:dimension]) if args[:dimension].present?
      { file_path: path, error: nil }
    rescue StandardError
      # A raised error leaves no half-written file behind in the served staging dir.
      cama_purge_staged_file(staged_path, tmp_path)
      raise
    ensure
      downloaded_tmp_file&.close!
    end

    # Message seam. Rendering user-facing upload errors differs by execution context,
    # so the pipeline never calls a translator directly.
    #
    # The defaults below are what a controller gets: CamaleonCms::CamaleonController does
    # not include CamaleonHelper, so `ct` is undefined there. CamaleonCms::UploaderHelper
    # overrides all three to route through `ct` / `cama_t` / `number_to_human_size`; `ct`
    # runs the `on_translation` hook that lets plugins override the text, which a shared
    # I18n.t call would silently drop.
    def cama_uploader_ct(key, args = {})
      I18n.t("camaleon_cms.common.#{key}", **args)
    end

    def cama_uploader_t(key, args = {})
      I18n.t(key, **args)
    end

    def cama_uploader_human_size(bytes)
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end

    private

    # Download remote files with SSRF guardrails: validate host/IP and reject redirects.
    # NOTE: UserUrlValidator.validate is intentionally called here even though the
    # crop_url controller path may have already validated the URL — this ensures
    # every caller of cama_tmp_upload is protected (defense-in-depth).
    def cama_download_remote_file(url)
      validator = UserUrlValidator.new
      validation_result = validator.validate(url, reject_path_traversal: true)
      return { error: validation_result.join(', ') } if validation_result.is_a?(Array)

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      # Pin the socket to the exact IP the validator vetted so a hostname whose DNS
      # answer changes between the SSRF check and the fetch (DNS rebinding) cannot
      # redirect the request to an internal address; SNI/cert checks keep the host.
      http.ipaddr = validator.resolved_ip if validator.resolved_ip
      http.open_timeout = 10
      http.read_timeout = 10
      response = http.start do |conn|
        conn.request(Net::HTTP::Get.new(uri.request_uri.presence || '/'))
      end

      return { error: 'Redirects are not allowed for remote uploads.' } if response.is_a?(Net::HTTPRedirection)

      unless response.is_a?(Net::HTTPSuccess)
        return { error: "Unable to download remote file (HTTP #{response.code})." }
      end

      # Enforce the site's maximum upload size to prevent memory exhaustion from oversized responses.
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

    def validate_file_format_or_error(file, formats)
      return if cama_uploader.class.validate_file_format(file, formats)

      { error: "#{cama_uploader_ct('file_format_error')} (#{formats})" }
    end

    # Stages a base64 data: payload into tmp_path, bounding its size and scanning its
    # content BEFORE the write, so nothing oversized or hostile ever reaches a path
    # the web server would hand out. Returns [path, error]; exactly one is non-nil.
    def cama_stage_data_uri(uploaded_io, args, tmp_path)
      return [nil, { error: cama_uploader_t('camaleon_cms.admin.media.name_required').to_s }] if args[:name].blank?

      # Strip any directory components so a hostile name (e.g. "../../etc/x")
      # cannot escape tmp_path when the base64 payload is written below.
      tmp_name = File.basename(args[:name].to_s)
      err = validate_file_format_or_error(tmp_name, args[:formats])
      return [nil, err] if err

      payload = uploaded_io.split(';base64,').last
      # Bound the payload before decoding, so an oversized upload is never allocated
      # in full nor written into the served staging directory.
      err = cama_size_limit_error(cama_base64_decoded_size(payload), args[:maximum])
      return [nil, err] if err

      # The decoded bytes are already in memory here, so scanning costs no extra copy.
      decoded = Base64.decode64(payload)
      return [nil, { error: 'Potentially malicious content found!' }] if content_unsafe?(decoded, filename: tmp_name)

      path = uploader_verify_name(File.join(tmp_path, tmp_name))
      return [nil, { error: 'Invalid file path' }] unless path_within?(path, tmp_path)

      File.open(path, 'wb') { |f| f.write(decoded) }
      [path, nil]
    end

    # Returns an error hash when size exceeds maximum, nil otherwise.
    def cama_size_limit_error(size, maximum)
      return if maximum.blank? || maximum >= size

      max_size = cama_uploader_human_size(maximum)
      { error: "#{cama_uploader_ct('file_size_exceeded', default: 'File size exceeded')} (#{max_size})" }
    end
  end
end
