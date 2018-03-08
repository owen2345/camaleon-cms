class CamaleonCmsAwsUploader < CamaleonCmsUploader
  def after_initialize
    @cloudfront = @aws_settings[:cloud_front] || @current_site.get_option("filesystem_s3_cloudfront")
    @aws_region = @aws_settings[:region] || @current_site.get_option("filesystem_region", 'us-west-2')
    @aws_akey = @aws_settings[:access_key] || @current_site.get_option("filesystem_s3_access_key")
    @aws_asecret = @aws_settings[:secret_key] || @current_site.get_option("filesystem_s3_secret_key")
    @aws_bucket = @aws_settings[:bucket] || @current_site.get_option("filesystem_s3_bucket_name")
    @aws_settings[:aws_file_upload_settings] ||= lambda{|settings| settings }
    @aws_settings[:aws_file_read_settings] ||= lambda{|data, s3_file| data }
  end

  # add a file object or file path into AWS server
  # :key => (String) key of the file to save in AWS
  # :args => (HASH) {same_name: false, is_thumb: false}, where:
  #   - same_name: false => avoid to overwrite an existent file with same key and search for an available key
  #   - is_thumb: true => if this file is a thumbnail of an uploaded file
  def add_file(uploaded_io_or_file_path, key, args = {})
    args = { same_name: false, is_thumb: false }.merge(args)

    # upload to aws
    s3_file = bucket.object(key[1..-1]) # remove first '/'
    s3_file.upload_file(uploaded_io_or_file_path.is_a?(String) ? uploaded_io_or_file_path : uploaded_io_or_file_path.path, acl: 'public-read' )

    # interrupt process if thumbnail
    return {} if args[:is_thumb]

    # Create DB record or override
    filename = key.split('/').last
    media_file = CamaleonCms::Media.find_or_create_by(
      site_id: @current_site.id,
      name: filename,
      folder_path: CamaleonCmsUploader.folder_path(key)
    ) do |f|
      f.file_size = args[:file_size]
      f.file_type = CamaleonCmsUploader.get_file_format(key)
      f.url = @cloudfront.present? ? @cloudfront + '/' + s3_file.key : s3_file.public_url
    end

    # Change name if changed case sensitivity
    if media_file[:name] != filename
      media_file.name = filename
      media_file.save
    end

    # Possible media error validations like duplications
    return media_file.errors.messages unless media_file.valid?

    media_file
  end

  # Will add only on DB, will be created on aws when uploading a file to it
  def add_folder(key)
    media_folder = CamaleonCms::Media.find_or_create_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key),
      is_folder: true
    ) do |f|
      # add name and folder again because of change in case sensitivity
      f.name = key.split('/').last
      f.folder_path = CamaleonCmsUploader.folder_path(key)
    end

    media_folder
  end

  def delete_folder(key)
    main_folder = CamaleonCms::Media.find_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key),
      is_folder: true
    )

    files = CamaleonCms::Media.where(site_id: @current_site.id, folder_path: key)
    inner_folders_files = CamaleonCms::Media.where(site_id: @current_site.id)
                                            .where('folder_path like ?', key + '/%')

    if main_folder.present?
      # destroy from DB
      main_folder.destroy
      files.destroy_all
      inner_folders_files.destroy_all

      # destroy complete folder on s3
      key = "#{@aws_settings['inner_folder']}/#{key}" if @aws_settings['inner_folder'].present?
      bucket.objects(prefix: key.split('/').clean_empty.join('/') << '/').delete
    end

    @instance.hooks_run('after_delete_folder', key)
  end

  def delete_file(key)
    media_file = CamaleonCms::Media.find_by(
      site_id: @current_site.id,
      name: key.split('/').last,
      folder_path: CamaleonCmsUploader.folder_path(key)
    )

    # destroy from db
    media_file.destroy if media_file.present?

    # remove from s3
    key = "#{@aws_settings['inner_folder']}/#{key}" if @aws_settings['inner_folder'].present?
    bucket.object(key.split('/').clean_empty.join('/')).delete rescue ''

    # remove also thumb from s3
    thumb_key = CamaleonCmsUploader.thumbnail(key)
    bucket.object(thumb_key.split('/').clean_empty.join('/')).delete rescue ''

    @instance.hooks_run('after_delete_file', key)
  end

  # initialize a bucket with AWS configurations
  # return: (AWS Bucket object)
  def bucket
    @bucket ||= lambda{
      config = Aws.config.update({ region: @aws_region, credentials: Aws::Credentials.new(@aws_akey, @aws_asecret) })
      s3 = Aws::S3::Resource.new
      bucket = s3.bucket(@aws_bucket)
    }.call
  end
end
