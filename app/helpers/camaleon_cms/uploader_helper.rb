module CamaleonCms::UploaderHelper
  include ActionView::Helpers::NumberHelper
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
  #   versions: (String) Create addtional multiple versions of the image uploaded, sample: '300x300,505x350' ==> Will create two extra images with these dimensions
  #       sample "test.png", versions: '200x200,450x450' will generate: thumb/test-png_200x200.png, test-png_450x450.png
  #   thumb_size: String (redefine the dimensions of the thumbnail, sample: '100x100' ==> only for images)
  #   temporal_time: if great than 0 seconds, then this file will expire (removed) in that time (default: 0)
  #     To manage jobs, please check http://edgeguides.rubyonrails.org/active_job_basics.html
  #     Note: if you are using temporal_time, you will need to copy the file to another directory later
  # sample: upload_file(params[:my_file], {formats: "images", folder: "temporal"})
  # sample: upload_file(params[:my_file], {formats: "jpg,png,gif,mp3,mp4", temporal_time: 10.minutes, maximum: 10.megabytes})
  def upload_file(uploaded_io, settings = {})
    cached_name = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.original_filename : nil
    return {error: "File is empty", file: nil, size: nil} unless uploaded_io.present?
    if uploaded_io.is_a?(String) && (uploaded_io.start_with?("http://") || uploaded_io.start_with?("https://")) # download url file
      tmp = cama_tmp_upload(uploaded_io)
      return tmp if tmp[:error].present?
      settings[:remove_source] = true
      uploaded_io = tmp[:file_path]
    end
    uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
    uploaded_io = File.open(cama_resize_upload(uploaded_io.path, settings[:dimension])) if settings[:dimension].present? # resize file into specific dimensions

    settings = settings.to_sym
    settings[:uploaded_io] = uploaded_io
    settings = {
        folder: "",
        maximum: current_site.get_option('filesystem_max_size', 100).to_f.megabytes,
        formats: "*",
        generate_thumb: true,
        temporal_time: 0,
        filename: ((cached_name || uploaded_io.original_filename) rescue uploaded_io.path.split("/").last).cama_fix_filename,
        file_size: File.size(uploaded_io.to_io),
        remove_source: false,
        same_name: false,
        versions: '',
        thumb_size: nil
    }.merge(settings)
    hooks_run("before_upload", settings)
    res = {error: nil}

    # formats validations
    return {error: "#{ct("file_format_error")} (#{settings[:formats]})"} unless cama_uploader.class.validate_file_format(uploaded_io.path, settings[:formats])

    # file size validations
    if settings[:maximum] < settings[:file_size]
      res[:error] = "#{ct("file_size_exceeded", default: "File size exceeded")} (#{number_to_human_size(settings[:maximum])})"
      return res
    end
    # save file
    key = File.join(settings[:folder], settings[:filename]).to_s.cama_fix_slash
    res = cama_uploader.add_file(uploaded_io, key, {same_name: settings[:same_name]})
    {} if settings[:temporal_time] > 0 # temporal file upload (always put as local for temporal files) (TODO: use delayjob)

    # generate image versions
    if res['format'] == 'image'
      settings[:versions].to_s.gsub(' ', '').split(',').each do |v|
        version_path = cama_resize_upload(uploaded_io.path, v, {replace: false})
        cama_uploader.add_file(version_path, cama_uploader.version_path(res['key'], v), is_thumb: true, same_name: true)
        FileUtils.rm_f(version_path)
      end
    end

    # generate thumb
    cama_uploader_generate_thumbnail(uploaded_io.path, res['key'], settings[:thumb_size]) if settings[:generate_thumb] && res['thumb'].present?

    FileUtils.rm_f(uploaded_io.path) if settings[:remove_source]
    res
  end

  # generate thumbnail of a existent image
  # key: key of the current file
  # the thumbnail will be saved in my_images/my_img.png => my_images/thumb/my_img.png
  def cama_uploader_generate_thumbnail(uploaded_io, key, thumb_size = nil)
    w, h = cama_uploader.thumb[:w], cama_uploader.thumb[:h]
    w, h = thumb_size.split('x') if thumb_size.present?
    uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
    path_thumb = cama_resize_and_crop(uploaded_io.path, w, h)
    thumb = cama_uploader.add_file(path_thumb, cama_uploader.version_path(key), is_thumb: true, same_name: true)
    FileUtils.rm_f(path_thumb)
    thumb
  end

  # helper to find an available filename for file_path in that directory
  # sample: uploader_verify_name("/var/www/my_image.jpg")
  #   return "/var/www/my_image_1.jpg" => if "/var/www/my_image.jpg" exist
  #   return "/var/www/my_image.jpg" => if "/var/www/my_image.jpg" doesn't exist
  def uploader_verify_name(file_path)
    dir, filename = File.dirname(file_path), File.basename(file_path).to_s.cama_fix_filename
    files = Dir.entries(dir)
    if files.include?(filename)
      i, _filename = 1, filename
      while files.include?(_filename) do
        _filename = "#{File.basename(filename, File.extname(filename))}_#{i}#{File.extname(filename)}"
        i += 1
      end
      filename = _filename
    end
    "#{File.dirname(file_path)}/#{filename}"
  end

  # convert downloaded file path into public url
  def cama_file_path_to_url(file_path)
    file_path.sub(Rails.public_path.to_s, (root_url rescue cama_root_url))
  end

  # convert public url to file path
  def cama_url_to_file_path(url)
    File.join(Rails.public_path, URI(url.to_s).path)
  end

  # crop and image and saved as imagename_crop.ext
  # file: file path
  # w:  new width
  # h: new height
  # w_offset: left offset
  # w_offset: top offset
  # resize: true/false
  #   (true => resize the image to this dimension)
  #   (false => crop the image with this dimension)
  # replace: Boolean (replace current image or create another file)
  def cama_crop_image(file_path, w=nil, h=nil, w_offset = 0, h_offset = 0, resize = false , replace = true)
    force = ""
    force = "!" if w.present? && h.present? && !w.include?("?") && !h.include?("?")
    image = MiniMagick::Image.open(file_path)
    w = image[:width].to_f > w.sub('?', '').to_i ? w.sub('?', "") : image[:width] if w.present? && w.to_s.include?('?')
    h = image[:height].to_f > h.sub('?', '').to_i ? h.sub('?', "") : image[:height] if h.present? && h.to_s.include?('?')
    image.combine_options do |i|
      i.resize("#{w if w.present?}x#{h if h.present?}#{force}") if resize
      i.crop "#{w if w.present?}x#{h if h.present?}+#{w_offset}+#{h_offset}#{force}" unless resize
    end

    res = file_path
    unless replace
      ext = File.extname(file_path)
      res = file_path.gsub(ext, "_crop#{ext}")
    end
    image.write res
    res
  end

  # resize and crop a file
  # Params:
  #   file: (String) File path
  #   w: (Integer) width
  #   h: (Integer) height
  #   settings:
  #     gravity: (Sym, default :north_east) Crop position: :north_west, :north, :north_east, :east, :south_east, :south, :south_west, :west, :center
  #     overwrite: (Boolean, default true) true for overwrite current image with resized resolutions, false: create other file called with prefix "crop_"
  #     output_name: (String, default prefixd name with crop_), permit to define the output name of the thumbnail if overwrite = true
  # Return: (String) file path where saved this cropped
  # sample: cama_resize_and_crop(my_file, 200, 200, {gravity: :north_east, overwrite: false})
  def cama_resize_and_crop(file, w, h, settings = {})
    settings = {gravity: :north_east, overwrite: true, output_name: ""}.merge(settings)
    img = MiniMagick::Image.open(file)
    w = img[:width].to_f > w.sub('?', '').to_i ? w.sub('?', "") : img[:width] if w.present? && w.to_s.include?('?')
    h = img[:height].to_f > h.sub('?', '').to_i ? h.sub('?', "") : img[:height] if h.present? && h.to_s.include?('?')
    w_original, h_original = [img[:width].to_f, img[:height].to_f]
    w = w.to_i if w.present?
    h = h.to_i if h.present?

    # check proportions
    if w_original * h < h_original * w
      op_resize = "#{w.to_i}x"
      w_result = w
      h_result = (h_original * w / w_original)
    else
      op_resize = "x#{h.to_i}"
      w_result = (w_original * h / h_original)
      h_result = h
    end

    w_offset, h_offset = cama_crop_offsets_by_gravity(settings[:gravity], [w_result, h_result], [ w, h])
    img.combine_options do |i|
      i.resize(op_resize)
      i.gravity(settings[:gravity])
      i.crop "#{w.to_i}x#{h.to_i}+#{w_offset}+#{h_offset}!"
    end

    img.write(file) if settings[:overwrite]
    unless settings[:overwrite]
      if settings[:output_name].present?
        img.write(file = File.join(File.dirname(file), settings[:output_name]).to_s)
      else
        img.write(file = uploader_verify_name(File.join(File.dirname(file), "crop_#{File.basename(file)}")))
      end
    end
    file
  end

  # upload tmp file
  # support for url and local path
  # sample:
  # cama_tmp_upload('http://camaleon.tuzitio.com/media/132/logo2.png')  ==> /var/rails/my_project/public/tmp/1/logo2.png
  # cama_tmp_upload('/var/www/media/132/logo 2.png')  ==> /var/rails/my_project/public/tmp/1/logo-2.png
  # accept args:
  #   name: to indicate the name to use, sample: cama_tmp_upload('/var/www/media/132/logo 2.png', {name: 'owen.png', formats: 'images'})
  #   formats: extensions permitted, sample: jpg,png,... or generic: images | videos | audios | documents (default *)
  #   dimension: 20x30
  # return: {file_path, error}
  def cama_tmp_upload(uploaded_io, args = {})
    tmp_path = args[:path] || Rails.public_path.join("tmp", current_site.id.to_s)
    FileUtils.mkdir_p(tmp_path) unless Dir.exist?(tmp_path)
    saved = false
    if uploaded_io.is_a?(String) && (uploaded_io.start_with?("data:")) # create tmp file using base64 format
      _tmp_name = args[:name]
      return {error: "#{cama_t("camaleon_cms.admin.media.name_required")}"} unless params[:name].present?
      return {error: "#{ct("file_format_error")} (#{args[:formats]})"} unless cama_uploader.class.validate_file_format(_tmp_name, args[:formats])
      path = uploader_verify_name(File.join(tmp_path, _tmp_name))
      File.open(path, 'wb'){|f| f.write(Base64.decode64(uploaded_io.split(';base64,').last)) }
      uploaded_io = File.open(path)
      saved =  true
    elsif uploaded_io.is_a?(String) && (uploaded_io.start_with?("http://") || uploaded_io.start_with?("https://"))
      return {error: "#{ct("file_format_error")} (#{args[:formats]})"} unless cama_uploader.class.validate_file_format(uploaded_io, args[:formats])
      uploaded_io = Rails.public_path.join(uploaded_io.sub(current_site.the_url(locale: nil), '')).to_s if uploaded_io.include?(current_site.the_url(locale: nil)) # local file
      _tmp_name = uploaded_io.split("/").last.split('?').first; args[:name] = args[:name] || _tmp_name
      uploaded_io = open(uploaded_io)
    end
    uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
    return {error: "#{ct("file_format_error")} (#{args[:formats]})"} unless cama_uploader.class.validate_file_format(_tmp_name || uploaded_io.path, args[:formats])
    return {error: "#{ct("file_size_exceeded", default: "File size exceeded")} (#{number_to_human_size(args[:maximum])})"} if args[:maximum].present? && args[:maximum] < (uploaded_io.size rescue File.size(uploaded_io))
    name = args[:name] || uploaded_io.path.split("/").last; name = "#{File.basename(name, File.extname(name)).underscore}#{File.extname(name)}"
    path ||= uploader_verify_name(File.join(tmp_path, name))
    File.open(path, "wb"){|f| f.write(uploaded_io.read) } unless saved
    path = cama_resize_upload(path, args[:dimension]) if args[:dimension].present?
    {file_path: path, error: nil}
  end

  # resize image if the format is correct
  # return resized file path
  def cama_resize_upload(image_path, dimesion, args = {})
    if cama_uploader.class.validate_file_format(image_path, 'image') && dimesion.present?
      r= {file: image_path, w: dimesion.split('x')[0], h: dimesion.split('x')[1], w_offset: 0, h_offset: 0, resize: !dimesion.split('x')[2] || dimesion.split('x')[2] == "resize", replace: true, gravity: :north_east}.merge(args); hooks_run("on_uploader_resize", r)
      if r[:w].present? && r[:h].present?
        image_path = cama_resize_and_crop(r[:file], r[:w], r[:h], {overwrite: r[:replace], gravity: r[:gravity] })
      else
        image_path = cama_crop_image(r[:file], r[:w], r[:h], r[:w_offset], r[:h_offset], r[:resize] , r[:replace])
      end
    end
    image_path
  end

  # return the current uploader
  def cama_uploader
    @cama_uploader ||= lambda{
      thumb = current_site.get_option('filesystem_thumb_size', '100x100').split('x')
      args= {
        server: current_site.get_option("filesystem_type", "local").downcase,
        thumb: {w: thumb[0], h: thumb[1]},
        aws_settings: {
          region: current_site.get_option("filesystem_region", 'us-west-2'),
          access_key: current_site.get_option("filesystem_s3_access_key"),
          secret_key: current_site.get_option("filesystem_s3_secret_key"),
          bucket: current_site.get_option("filesystem_s3_bucket_name"),
          cloud_front: current_site.get_option("filesystem_s3_cloudfront"),
          aws_file_upload_settings: lambda{|settings| settings }, # permit to add your custom attributes for file_upload http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#upload_file-instance_method
          aws_file_read_settings: lambda{|data, s3_file| data } # permit to read custom attributes from aws file and add to file parsed object
        }
      }
      hooks_run("on_uploader", args)
      case args[:server]
        when 's3', 'aws'
          CamaleonCmsAwsUploader.new({current_site: current_site, thumb: args[:thumb], aws_settings: args[:aws_settings]})
        else
          CamaleonCmsLocalUploader.new({current_site: current_site, thumb: args[:thumb]})
      end
    }.call
  end

  private
  # helper for resize and crop method
  def cama_crop_offsets_by_gravity(gravity, original_dimensions, cropped_dimensions)
    original_width, original_height = original_dimensions
    cropped_width, cropped_height = cropped_dimensions

    vertical_offset = case gravity
                        when :north_west, :north, :north_east then 0
                        when :center, :east, :west then [ ((original_height - cropped_height) / 2.0).to_i, 0 ].max
                        when :south_west, :south, :south_east then (original_height - cropped_height).to_i
                      end

    horizontal_offset = case gravity
                          when :north_west, :west, :south_west then 0
                          when :center, :north, :south then [ ((original_width - cropped_width) / 2.0).to_i, 0 ].max
                          when :north_east, :east, :south_east then (original_width - cropped_width).to_i
                        end

    return [ horizontal_offset, vertical_offset ]
  end

  # convert file path into thumb path format
  # return the image name into thumb format: owewen.png into thumb/owen-png.png
  def cama_parse_for_thumb_name(file_path)
    "#{@fog_connection_hook_res[:thumb_folder_name]}/#{File.basename(file_path).parameterize}#{File.extname(file_path)}"
  end
end
