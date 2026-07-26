# frozen_string_literal: true

module CamaleonCms
  # Uploader backend resolution plus the filename and URL helpers that the staging
  # and image-processing pipelines build on. Shared by the two uploader entry points,
  # CamaleonCms::RuntimeUploaderConcern and CamaleonCms::UploaderHelper.
  module UploaderSupport
    # return the current uploader
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
            # permit to add your custom attributes for
            # file_upload https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#upload_file-instance_method
            aws_file_upload_settings: ->(settings) { settings },
            # permit to read custom attributes from aws file and add to file parsed object
            aws_file_read_settings: ->(data, _s3_file) { data }
          },
          custom_uploader: nil # possibility to use custom file uploader
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

    # helper to find an available filename for file_path in that directory
    # sample: uploader_verify_name("/var/www/my_image.jpg")
    #   return "/var/www/my_image_1.jpg" => if "/var/www/my_image.jpg" exist
    #   return "/var/www/my_image.jpg" => if "/var/www/my_image.jpg" doesn't exist
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

    # convert downloaded file path into public url
    def cama_file_path_to_url(file_path)
      file_path.sub(Rails.public_path.to_s, begin
        root_url
      rescue StandardError
        cama_root_url
      end)
    end

    # convert public url to file path
    def cama_url_to_file_path(url)
      File.join(Rails.public_path, URI(url.to_s).path)
    end

    def slugify(val)
      val.to_s.downcase.strip.tr(' ', '-').gsub(/[^\w-]/, '')
    end

    def slugify_folder(val)
      split_folder = val.split('/')
      split_folder[-1] = slugify(split_folder[-1])
      split_folder.join('/')
    end
  end
end
