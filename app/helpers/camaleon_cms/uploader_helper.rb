=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::UploaderHelper
  # upload a file into server
  # settings:
  #   folder: Directory where the file will be saved (default: "")
  #     sample: temporal => will save in /rails_path/public/temporal
  #   generate_thumb: true, # generate thumb image if this is image format (default true)
  #   maximum: maximum bytes permitted to upload (default: 1000MG)
  #   dimension: dimension for the image (sample: 30x30 | x30 | 30x)
  #   formats: extensions permitted, sample: jpg,png,... or generic: images | videos | audios | documents (default *)
  #   remove_source: Boolean (delete source file after saved if this is true, default false)
  #   same_name: Boolean (save the file with the same name if defined true, else search for a non used name)
  #   temporal_time: if great than 0 seconds, then this file will expire (removed) in that time (default: 0)
  #     To manage jobs, please check http://edgeguides.rubyonrails.org/active_job_basics.html
  #     Note: if you are using temporal_time, you will need to copy the file to another directory later
  # sample: upload_file(params[:my_file], {formats: "images", folder: "temporal"})
  # sample: upload_file(params[:my_file], {formats: "jpg,png,gif,mp3,mp4", temporal_time: 10.minutes, maximum: 10.megabytes})
  def upload_file(uploaded_io, settings = {})
    unless uploaded_io.present?
      return {error: "File is empty", file: nil, size: nil}
    end
    uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)

    uploaded_io = File.open(cama_resize_upload(uploaded_io.path, settings[:dimension])) if settings[:dimension].present? # resize file into specific dimensions

    cama_uploader_init_connection(true)
    settings = settings.to_sym
    settings[:uploaded_io] = uploaded_io
    settings = {
        folder: "",
        maximum: 100.megabytes,
        formats: "*",
        generate_thumb: true,
        temporal_time: 0,
        filename: (uploaded_io.original_filename rescue uploaded_io.path.split("/").last).parameterize(".").downcase.gsub(" ", "-"),
        file_size: File.size(uploaded_io.to_io),
        remove_source: false,
        same_name: false
    }.merge(settings)
    hooks_run("before_upload", settings)

    res = {error: nil}

    # formats validations
    return {error: "#{ct("file_format_error")} (#{settings[:formats]})"} unless cama_verify_format(uploaded_io.path, settings[:formats])

    # file size validations
    if settings[:maximum] < settings[:file_size]
      res[:error] = ct("file_size_exceeded")
      return res
    end

    File.chmod(0644, uploaded_io.path) # fix reading permission (Fix Fog-Local)

    # save file
    if settings[:same_name]
      partial_path = "#{current_site.upload_directory_name}/#{"#{settings[:folder]}/" if settings[:folder].present?}#{settings[:filename]}"
    else
      partial_path = "#{current_site.upload_directory_name}/#{cama_uploader_check_name("#{"#{settings[:folder]}/" if settings[:folder].present?}#{settings[:filename]}")}"
    end
    partial_path = partial_path.gsub(/(\/){2,}/, "/")
    file = @fog_connection_bucket_dir.files.create({:key => partial_path, :body => uploaded_io, :public => true})

    if settings[:temporal_time] > 0 # temporal file upload (always put as local for temporal files)
      Thread.new do
        sleep(settings[:temporal_time])
        file.destroy
        ActiveRecord::Base.connection.close
      end
    end

    res = cama_uploader_parse_file(file)

    # generate thumb
    if settings[:generate_thumb] && res["format"] == "image" && File.extname(file.key) != ".gif"

      cama_uploader_generate_thumbnail(uploaded_io.path, file.key, settings[:folder].split("/").push(@fog_connection_hook_res[:thumb_folder_name]).join("/"))
    end
    FileUtils.rm_f(uploaded_io.path) if settings[:remove_source]
    res
  end

  # generate thumbnail
  def cama_uploader_generate_thumbnail(source_path, filename, folder)
    thumb_name = cama_parse_for_thumb_name(filename)
    path_thumb = cama_resize_and_crop(source_path, @fog_connection_hook_res[:thumb][:w], @fog_connection_hook_res[:thumb][:h], {overwrite: false, output_name: thumb_name.split("/").last})
    upload_file(path_thumb, {generate_thumb: false, same_name: true, remove_source: true, folder: folder})
  end

  # destroy file from fog
  # sample: "owen/campaign-date-picker_1.png"
  def cama_uploader_destroy_file(file_path, destroy_thumb = true)
    cama_uploader_init_connection(true)
    file = @fog_connection_bucket_dir.files.head("#{current_site.upload_directory_name}/#{file_path}".gsub(/(\/){2,}/, "/"))
    _file =  cama_uploader_parse_file(file)
    if destroy_thumb && _file["format"] == "image" && File.extname(file_path) != ".gif" # destroy thumb
      cama_uploader_destroy_file("#{File.dirname(file_path)}/#{cama_parse_for_thumb_name(file.key)}", false) rescue ""
    end
    file.destroy
  end

  # destroy a folder from fog
  def cama_uploader_destroy_folder(folder)
    cama_uploader_init_connection(true)
    if @fog_connection.class.name.include?("AWS")
      dir = @fog_connection.directories.get(@fog_connection_hook_res[:bucket_name], prefix: "#{current_site.upload_directory_name}/#{folder}".gsub(/(\/){2,}/, "/"))
      dir.files.each{|f| f.destroy }
    end
    @fog_connection_bucket_dir.files.head("#{current_site.upload_directory_name}/#{folder}/".gsub(/(\/){2,}/, "/")).destroy rescue ""
  end

  # add a new folder in fog
  def cama_uploader_add_folder(folder)
    cama_uploader_init_connection(true)
    key = "#{@fog_connection_hook_res[:bucket_name]}/#{current_site.upload_directory_name}/#{folder}/".split("/").clean_empty.join("/")
    dir = @fog_connection.directories.create(:key => key)
    dir.files.create({:key => '_tmp.txt', content: "", :public => true}) unless @fog_connection.class.name.include?("AWS")
  end

  # initialize fog uploader and trigger hook to customize fog storage
  def cama_uploader_init_connection(clear_cache = false)
    server = current_site.get_option("filesystem_type", "local")
    @fog_connection_hook_res ||= {server: server, connection: nil, thumb_folder_name: "thumb", bucket_name: server == "local" ? "media" : current_site.get_option("filesystem_s3_bucket_name"), thumb: {w: 100, h: 100}}; hooks_run("on_uploader", @fog_connection_hook_res)
    case @fog_connection_hook_res[:server]
      when "local"
        Dir.mkdir(Rails.root.join("public", @fog_connection_hook_res[:bucket_name]).to_s) unless Dir.exist?(Rails.root.join("public", @fog_connection_hook_res[:bucket_name]).to_s)
        @fog_connection ||= !@fog_connection_hook_res[:connection].present? ? Fog::Storage.new({ :local_root => Rails.root.join("public").to_s, :provider   => 'Local', endpoint: (root_url rescue cama_root_url) }) : @fog_connection_hook_res[:connection]
      when "s3"
        @fog_connection ||= !@fog_connection_hook_res[:connection].present? ? Fog::Storage.new({ :aws_access_key_id => current_site.get_option("filesystem_s3_access_key"), :provider   => 'AWS', aws_secret_access_key: current_site.get_option("filesystem_s3_secret_key"), :region  => current_site.get_option("filesystem_region") }) : @fog_connection_hook_res[:connection]
    end
    @fog_connection_bucket_dir ||= @fog_connection.directories.get(@fog_connection_hook_res[:bucket_name])
    current_site.set_meta("cache_browser_files_#{@fog_connection_hook_res}", nil) if clear_cache
  end

  # verify if this file name already exist
  # if the file is already exist, return a new name for this file
  # sample: cama_uploader_check_name("my_file/file.txt")
  def cama_uploader_check_name(partial_path)
    cama_uploader_init_connection()
    files = @fog_connection_bucket_dir.files
    res = partial_path
    if files.head("#{current_site.upload_directory_name}/#{res}".gsub(/(\/){2,}/, "/")).present?
      dirname = "#{File.dirname(partial_path)}/" if partial_path.include?("/")
      (1..999).each do |i|
        res = "#{dirname}#{File.basename(partial_path, File.extname(partial_path))}_#{i}#{File.extname(partial_path)}"
        break unless files.head("#{current_site.upload_directory_name}/#{res}".gsub(/(\/){2,}/, "/")).present?
      end
    end
    res.gsub(/(\/){2,}/, "/")
  end

  # search a folder by path and return all folders and files
  # sample: cama_media_find_folder("test/exit")
  def cama_media_find_folder(path = "")
    cama_uploader_init_connection(true)

    prefix  = "#{current_site.upload_directory_name}/#{path}/".gsub(/(\/){2,}/, "/")
    res     = {folders: {}, files: []}

    @fog_connection.directories.get(@fog_connection_hook_res[:bucket_name], prefix: prefix).files.each do |file|
      res[:files] << cama_uploader_parse_file(file) if file.key =~ %r|#{prefix}[^/]+$| && !file.key.include?('/_tmp.txt')
      if file.key =~ %r|#{prefix}([^/]+)/|
        folder_name = "#{$~[1]}"
        res[:folders][folder_name] = {folders: {}, files: []} unless (folder_name == @fog_connection_hook_res[:thumb_folder_name])
      end
    end
    return res
  end

  # search for a file by filename
  # sample: cama_media_search_file("")
  def cama_media_search_file(filename)
    cama_uploader_init_connection(true)

    prefix  = current_site.upload_directory_name.gsub(/(\/){2,}/, "/")

    @fog_connection.directories
    .get(@fog_connection_hook_res[:bucket_name], prefix: prefix)
    .files
    .select { |file| file.key.split('/').last.include?(filename) && !file.key.include?('/_tmp.txt') }
    .map { |file| cama_uploader_parse_file(file) }
  end

  # parse file information of FOG file
  def cama_uploader_parse_file(file)
    res = {"name"=> File.basename(file.key), "file"=> file.key, "size"=> file.content_length, "url"=> (file.public_url rescue [current_site.get_option("filesystem_s3_endpoint"), file.key ].join("/")), "deleteUrl"=> "" }
    ext = File.extname(file.key).sub(".", "").downcase
    res["format"] = "unknown"
    if "jpg,jpeg,png,gif,bmp,ico".split(",").include?(ext)
      if File.extname(res["name"]) == ".gif"
        res["thumb"] = res["url"]
      else
        res["thumb"] = "#{File.dirname(res["url"])}/#{cama_parse_for_thumb_name(file.key)}" rescue ""
      end
      res["format"] = "image"
    end
    if "flv,webm,wmv,avi,swf,mp4".split(",").include?(ext)
      res["format"] = "video"
    end
    if "mp3,ogg".split(",").include?(ext)
      res["format"] = "audio"
    end
    if "pdf,xls,xlsx,doc,docx,ppt,pptx,html,txt,xml,json".split(",").include?(ext)
      res["format"] = "document"
    end
    if "zip,7z,rar,tar,bz2,gz,rar2".split(",").include?(ext)
      res["format"] = "compress"
    end
    res["type"] = (MIME::Types.type_for(file.key).first.content_type rescue "")
    res
  end

  # helper to find an available filename for file_path in that directory
  # sample: uploader_verify_name("/var/www/my_image.jpg")
  #   return "/var/www/my_image_1.jpg" => if "/var/www/my_image.jpg" exist
  #   return "/var/www/my_image.jpg" => if "/var/www/my_image.jpg" doesn't exist
  def uploader_verify_name(file_path)
    dir, filename = File.dirname(file_path), File.basename(file_path)
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
  def cama_tmp_upload(uploaded_io, args = {})
    tmp_path = args[:path] || Rails.public_path.join("tmp", current_site.id.to_s)
    FileUtils.mkdir_p(tmp_path) unless Dir.exist?(tmp_path)
    if uploaded_io.is_a?(String) && (uploaded_io.start_with?("http://") || uploaded_io.start_with?("https://"))
      return {error: "#{ct("file_format_error")} (#{args[:formats]})"} unless cama_verify_format(uploaded_io, args[:formats])
      name = args[:name] || uploaded_io.split("/").last
      name = "#{File.basename(name, File.extname(name)).underscore}#{File.extname(name)}"
      path = uploader_verify_name( File.join(tmp_path, name))
      File.open(path, 'wb'){|file| file.write(open(uploaded_io).read) }
      path = cama_resize_upload(path, args[:dimension]) if args[:dimension].present?
    else
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      return {error: "#{ct("file_format_error")} (#{args[:formats]})"} unless cama_verify_format(uploaded_io.path, args[:formats])
      name = args[:name] || uploaded_io.path.split("/").last
      name = "#{File.basename(name, File.extname(name)).underscore}#{File.extname(name)}"
      path = uploader_verify_name( File.join(tmp_path, name))
      File.open(path, "wb"){|f| f.write(uploaded_io.read) }
      path = cama_resize_upload(path, args[:dimension]) if args[:dimension].present?
    end
    {file_path: path, error: nil}
  end

  # resize image if the format is correct
  # return resized file path
  def cama_resize_upload(image_path, dimesion)
    if cama_verify_format(image_path, 'image') && dimesion.present?
      r={file: image_path, w: dimesion.split('x')[0], h: dimesion.split('x')[1], w_offset: 0, h_offset: 0, resize: !dimesion.split('x')[2] || dimesion.split('x')[2] == "resize", replace: true, gravity: :north_east}; hooks_run("on_uploader_resize", r)
      if r[:w].present? && r[:h].present?
        image_path = cama_resize_and_crop(r[:file], r[:w], r[:h], {overwrite: r[:replace], gravity: r[:gravity] })
      else
        image_path = cama_crop_image(r[:file], r[:w], r[:h], r[:w_offset], r[:h_offset], r[:resize] , r[:replace])
      end
    end
    image_path
  end

  # verify permitted formats (return boolean true | false)
  # true: if format is accepted
  # false: if format is not accepted
  # sample: cama_verify_format(file_path, 'image,audio,docx,xls') => return true if the file extension is in formats
  def cama_verify_format(file_path, formats)
    return true if formats == "*" || !formats.present?
    formats = formats.downcase.split(",")
    if formats.include? "image"
      formats += "jpg,jpeg,png,gif,bmp,ico".split(',')
    end
    if formats.include? "video"
      formats += "flv,webm,wmv,avi,swf,mp4".split(',')
    end
    if formats.include? "audio"
      formats += "mp3,ogg".split(',')
    end
    if formats.include? "document"
      formats += "pdf,xls,xlsx,doc,docx,ppt,pptx,html,txt,htm,json,xml".split(',')
    end
    if formats.include?("compress") || formats.include?("compres")
      formats += "zip,7z,rar,tar,bz2,gz,rar2".split(',')
    end
    formats.include?(File.extname(file_path).sub(".", "").downcase)
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
