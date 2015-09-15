=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module UploaderHelper
  # upload a file into server
  # settings:
  #   folder: Directory where the file will be saved (default: current_site.upload_directory)
  #     sample: temporal => will save in /rails_path/public/temporal
  #   maximum: maximum bytes permitted to upload (default: 1000MG)
  #   formats: extensions permitted, sample: jpg,png,... or generic: images | videos | audios | documents (default *)
  #   create_folder: auto create folder if it doesn't exist (default: true)
  #   temporal_time: if great than 0 seconds, then this file will expire (removed) in that time (default: 0)
  #     To manage jobs, please check http://edgeguides.rubyonrails.org/active_job_basics.html
  #     Note: if you are using temporal_time, you will need to copy the file to another directory later
  # sample: upload_file(params[:my_file], {formats: "images", folder: "temporal"})
  # sample: upload_file(params[:my_file], {formats: "jpg,png,gif,mp3,mp4", temporal_time: 10.minutes, maximum: 10.megabytes})
  def upload_file(uploaded_io, settings = {})
    unless uploaded_io.present?
      return {error: "File is empty", file: nil, size: nil}
    end
    settings = settings.to_sym
    filename = uploaded_io.original_filename.parameterize(".").downcase.gsub(" ", "-")
    res = {error: nil, file: filename, size: File.size(uploaded_io.to_io)}
    #settings[:folder] = File.join(Rails.public_path, settings[:folder]) if settings[:folder].present?
    settings = {
        folder: current_site.upload_directory,
        maximum: 100.megabytes,
        formats: "*",
        create_folder: true,
        temporal_time: 0
      }.merge(settings)
    settings[:folder] = settings[:folder].to_s
    if settings[:create_folder] && !File.directory?(settings[:folder])
      FileUtils.mkdir_p(settings[:folder])
      FileUtils.chmod(0777, settings[:folder])
    end

    # folder validation
    unless File.directory?(settings[:folder])
      res[:error] = "Directory not found"
      return res
    end


    file_path = uploader_verify_name(File.join(settings[:folder], filename).to_s)

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

      unless settings[:formats].downcase.split(",").include?(File.extname(file_path).sub(".", "").downcase)
        res[:error] = ct("file_format_error")
        return res
      end
    end

    # file size validations
    if settings[:maximum] < File.size(uploaded_io.to_io)
      res[:error] = ct("file_size_exceeded")
      return res
    end

    begin
      File.open(file_path, 'wb') do |file|
        file.write(uploaded_io.read)
      end
    rescue => e
      res[:error] = e.message
      return res
    end

    # check for destroy the file in the future
    if settings[:temporal_time] > 0
      Thread.new do
        sleep(settings[:temporal_time])
        FileUtils.rm_rf(file_path) if File.exist?(file_path) && !File.directory?(file_path)
        ActiveRecord::Base.connection.close
      end
    end

    # returning data
    {
        "file" => file_path,
        "name"=> File.basename(file_path),
        "size"=> File.size(file_path),
        "url"=> file_path_to_url(file_path),
        "type"=> uploaded_io.content_type,
        "deleteUrl"=> ""
    }
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
  def file_path_to_url(file_path)
    file_path.sub(Rails.public_path.to_s, root_url)
  end

  # convert public url to file path
  def url_to_file_path(url)
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
  def crop_image(file, w, h, w_offset, h_offset, resize = nil )
    file_dir = File.join(Rails.public_path, file)
    puts "-------file_dir--------#{file_dir}----------"
    image = MiniMagick::Image.open(file_dir)
    image.combine_options do |i|
      i.resize(resize) if resize.present?
      i.crop "#{w.to_i}x#{h.to_i}+#{w_offset}+#{h_offset}!"
    end
    ext = File.extname(file_dir)
    image.write file_dir.gsub(ext, "_crop#{ext}")
    file.gsub(ext, "_crop#{ext}")
  end

  # resize and crop a file
  # Params:
  #   file: (String) File path
  #   w: (Integer) width
  #   h: (Integer) height
  #   gravity: (Sym, default :north_east) Crop position: :north_west, :north, :north_east, :east, :south_east, :south, :south_west, :west, :center
  #   overwrite: (Boolean, default true) true for overwrite current image with resized resolutions, false: create other file called with prefix "crop_"
  # Return: (String) file path where saved this cropped
  def cama_resize_and_crop(file, w, h, settings = {})
    settings = {gravity: :north_east, overwrite: true}.merge(settings)
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
    img.write(file = uploader_verify_name(File.join(File.dirname(file), "crop_#{File.basename(file)}"))) unless settings[:overwrite]
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
end
