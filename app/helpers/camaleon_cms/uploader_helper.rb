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
    cama_uploader_init_connection(true)
    settings = settings.to_sym
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

    res = {error: nil}

    # formats validations
    if settings[:formats] != "*"
      case settings[:formats]
        when "images"
          settings[:formats] = "jpg,jpeg,png,gif,bmp"
        when "videos"
          settings[:formats] = "flv,webm,wmv,avi,swf,mp4"
        when "audios"
          settings[:formats] = "mp3,ogg"
        when "documents"
          settings[:formats] = "pdf,xls,xlsx,doc,docx,ppt,pptx,html,txt"
        when "compresed"
          settings[:formats] = "zip,7z,rar,tar,bz2,gz,rar2"
      end

      unless settings[:formats].downcase.split(",").include?(File.extname(settings[:filename]).sub(".", "").downcase)
        res[:error] = ct("file_format_error")
        return res
      end
    end

    # file size validations
    if settings[:maximum] < settings[:file_size]
      res[:error] = ct("file_size_exceeded")
      return res
    end

    # save file
    if settings[:same_name]
      partial_path = "#{"#{current_site.id}"}/#{"#{settings[:folder]}/" if settings[:folder].present?}#{settings[:filename]}"
    else
      partial_path = "#{"#{current_site.id}"}/#{cama_uploader_check_name("#{"#{settings[:folder]}/" if settings[:folder].present?}#{settings[:filename]}")}"
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
      thumb_name = cama_parse_for_thumb_name(file.key)
      path_thumb = cama_resize_and_crop(uploaded_io.path, @fog_connection_hook_res[:thumb][:w], @fog_connection_hook_res[:thumb][:h], {overwrite: false, output_name: thumb_name.split("/").last})
      thumb_res = upload_file(path_thumb, {generate_thumb: false, same_name: true, remove_source: true, folder: settings[:folder].split("/").push(@fog_connection_hook_res[:thumb_folder_name]).join("/")})
    end
    FileUtils.rm_f(uploaded_io.path) if settings[:remove_source]
    res
  end

  # destroy file from fog
  # sample: "owen/campaign-date-picker_1.png"
  def cama_uploader_destroy_file(file_path, destroy_thumb = true)
    cama_uploader_init_connection(true)
    file = @fog_connection_bucket_dir.files.head("#{current_site.id}/#{file_path}".gsub(/(\/){2,}/, "/"))
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
      dir = @fog_connection.directories.get(@fog_connection_hook_res[:bucket_name], prefix: "#{current_site.id}/#{folder}".gsub(/(\/){2,}/, "/"))
      dir.files.each{|f| f.destroy }
    end
    @fog_connection_bucket_dir.files.head("#{current_site.id}/#{folder}/".gsub(/(\/){2,}/, "/")).destroy rescue ""
  end

  # add a new folder in fog
  def cama_uploader_add_folder(folder)
    cama_uploader_init_connection(true)
    key = "#{current_site.id}/#{folder}/".split("/").clean_empty.join("/")
    key += '/_tmp.txt' unless @fog_connection.class.name.include?("AWS")
    @fog_connection_bucket_dir.files.create({:key => key, content: "", :public => true})
  end

  # initialize fog uploader and trigger hook to customize fog storage
  def cama_uploader_init_connection(clear_cache = false)
    server = current_site.get_option("filesystem_type", "local")
    @fog_connection_hook_res ||= {server: server, connection: nil, thumb_folder_name: "thumb", bucket_name: server == "local" ? "media" : current_site.get_option("filesystem_s3_bucket_name"), thumb: {w: 100, h: 100}}; hooks_run("on_uploader", @fog_connection_hook_res)
    case server
      when "local"
        Dir.mkdir(Rails.root.join("public", "media").to_s) unless Dir.exist?(Rails.root.join("public", "media").to_s)
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
    if files.head("#{current_site.id}/#{res}".gsub(/(\/){2,}/, "/")).present?
      dirname = "#{File.dirname(partial_path)}/" if partial_path.include?("/")
      (1..999).each do |i|
        res = "#{dirname}#{File.basename(partial_path, File.extname(partial_path))}_#{i}#{File.extname(partial_path)}"
        break unless files.head("#{current_site.id}/#{res}".gsub(/(\/){2,}/, "/")).present?
      end
    end
    res.gsub(/(\/){2,}/, "/")
  end

  # Generate Hash structure of files from FOG
  def cama_uploader_browser_files(load_cache = true)
    if load_cache
      cache_res = current_site.get_meta("cache_browser_files_#{@fog_connection_hook_res}")
      return cache_res.with_indifferent_access if cache_res.present?
    end

    @browser_files = {folders: {}, files: [], path: ""}
    cama_uploader_init_connection()
    @fog_connection_bucket_dir.files.all.each do |file|
      cama_uploader_browser_files_parse_file(@browser_files, File.dirname(file.key), file)
    end
    current_site.set_meta("cache_browser_files_#{@fog_connection_hook_res}", @browser_files)
  end

  # add full file path into browser structure
  # sample: 1/500_3.html => {folders: { 1:{ folders:{}, files: [{name: 503.html, ..}] } } }
  def cama_uploader_browser_files_parse_file(folder_src, folder_dst, file)
    if folder_dst.present?
      return "" if folder_dst.start_with?(@fog_connection_hook_res[:thumb_folder_name]) # thumb folders ignored
      f = folder_dst.split("/").first
      folder_src[:folders][f] = {folders: {}, files: []} unless folder_src[:folders].keys.include?(f)
      cama_uploader_browser_files_parse_file(folder_src[:folders][f], folder_dst.split("/").from(1).join("/"), file)
    else
      if file.key.end_with?("/")
        folder_src[:folders][file.key.split("/").last] = {folders: {}, files: []}
      else
        r_file = cama_uploader_parse_file(file)
        folder_src[:files] << r_file if r_file["url"].present? && !file.key.include?('/_tmp.txt') # skip non public url files (protected)
      end
    end
  end

  # search a folder by path and return all folders and files
  # sample: cama_media_find_folder("test/exit")
  def cama_media_find_folder(path = "")
    res = nil
    folder = cama_uploader_browser_files[:folders]
    "#{current_site.id}/#{path}".gsub(/(\/){2,}/, "/").split("/").each do |k|
      if k.present?
        begin
          res =  folder[k]
          folder = folder[k][:folders]
        rescue
          break
        end
      end
    end
    res || {folders: {}, files: []}
  end

  # parse file information of FOG file
  def cama_uploader_parse_file(file)
    res = {"name"=> File.basename(file.key), "size"=> file.content_length, "url"=> (file.public_url rescue [current_site.get_option("filesystem_s3_endpoint"), file.key ].join("/")), "deleteUrl"=> "" }
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
    if "pdf,xls,xlsx,doc,docx,ppt,pptx,html,txt".split(",").include?(ext)
      res["format"] = "doc"
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
  def cama_crop_image(file_path, w, h, w_offset, h_offset, resize = nil , replace: true)
    image = MiniMagick::Image.open(file_path)
    image.combine_options do |i|
      i.resize(resize) if resize.present?
      i.crop "#{w.to_i}x#{h.to_i}+#{w_offset}+#{h_offset}!"
    end

    res = file_path
    if replace
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
    w_original, h_original = [img[:width].to_f, img[:height].to_f]

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
