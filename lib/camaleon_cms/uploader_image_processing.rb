# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName
module CamaleonCms
  # Image transformation shared by the two uploader entry points,
  # CamaleonCms::RuntimeUploaderConcern and CamaleonCms::UploaderHelper, so cropping
  # and resizing behave identically whichever one a caller included.
  module UploaderImageProcessing
    # generate thumbnail of a existent image
    # key: key of the current file
    # the thumbnail will be saved in my_images/my_img.png => my_images/thumb/my_img.png
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

    # resize and crop a file
    # SVGs are converted to JPEGs for editing
    # Params:
    #   file: (String) File path
    #   w: (Integer) width
    #   h: (Integer) height
    #   settings:
    #     gravity: (Sym, default :north_east)
    #       Crop position: :north_west, :north, :north_east, :east, :south_east, :south, :south_west, :west, :center
    #     overwrite: (Boolean, default true) true for overwrite current image with resized resolutions,
    #       false: create other file called with prefix "crop_"
    #     output_name: (String, default prefixd name with crop_), permit to define the output name of the
    #       thumbnail if overwrite = true
    # Return: (String) file path where saved this cropped
    # sample: cama_resize_and_crop(my_file, 200, 200, {gravity: :north_east, overwrite: false})
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

    # resize image if the format is correct
    # return resized file path
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

    private

    # helper for resize and crop method
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
  end
end
# rubocop:enable Naming/MethodParameterName
