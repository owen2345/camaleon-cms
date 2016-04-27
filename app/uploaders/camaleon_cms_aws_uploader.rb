class CamaleonCmsAwsUploader < CamaleonCmsUploader
  # recover all files from AWS and parse it to save into DB as cache
  def browser_files
    objects = {}
    objects['/'] = {files: {}, folders: {}}
    bucket.objects.each do |file|
      cache_item(file_parse(file), objects)
    end
    @current_site.set_meta('cama_media_cache', objects)
    objects
  end

  # parse an AWS file into custom file_object
  def file_parse(s3_file)
    key = s3_file.is_a?(String) ? s3_file : s3_file.key
    key = "/#{key}" unless key.starts_with?('/')
    is_dir = File.extname(key) == ''
    res = {
        "name" => File.basename(key),
        "key" => key,
        "url" => is_dir ? '' : (@current_site.get_option("filesystem_s3_cloudfront").present? ? File.join(@current_site.get_option("filesystem_s3_cloudfront"), key) : s3_file.public_url),
        "is_folder" => is_dir,
        "size" => is_dir ? 0 : s3_file.size.round(2),
        "format" => is_dir ? 'folder' : self.class.get_file_format(key),
        "deleteUrl" => '',
        "thumb" => '',
        'type' => is_dir ? '' : (s3_file.content_type rescue (MIME::Types.type_for(key).first.content_type rescue "")),
        'created_at' => is_dir ? '' : s3_file.last_modified,
        'dimension' => ''
    }.with_indifferent_access
    res["thumb"] = version_path(res['url']) if res['format'] == 'image' && File.extname(res['name']).downcase != '.gif'
    if res['format'] == 'image'
      # TODO: Recover image dimension (suggestion: save dimesion as metadata)
    end
    res
  end

  # add a file object or file path into AWS server
  # :key => (String) key of the file ot save in AWS
  # :args => (HASH) {same_name: false, is_thumb: false}, where:
  #   - same_name: false => avoid to overwrite an existent file with same key and search for an available key
  #   - is_thumb: true => if this file is a thumbnail of an uploaded file
  def add_file(uploaded_io_or_file_path, key, args = {})
    args, res = {same_name: false, is_thumb: false}.merge(args), nil
    key = search_new_key(key) unless args[:same_name]
    s3_file = bucket.object(key.split('/').clean_empty.join('/'))
    s3_file.upload_file(uploaded_io_or_file_path.is_a?(String) ? uploaded_io_or_file_path : uploaded_io_or_file_path.path, acl: 'public-read')
    res = cache_item(file_parse(s3_file)) unless args[:is_thumb]
    res
  end

  # add new folder to AWS with :key
  def add_folder(key)
    s3_file = bucket.object(key.split('/').clean_empty.join('/') << '/')
    s3_file.put(body: nil)
    cache_item(file_parse(s3_file))
    s3_file
  end

  # delete a folder in AWS with :key
  def delete_folder(key)
    bucket.objects(prefix: key.split('/').clean_empty.join('/') << '/').delete
    reload
  end

  # delete a file in AWS with :key
  def delete_file(key)
    bucket.object(key.split('/').clean_empty.join('/')).delete rescue ''
    reload
  end

  # initialize a bucket with AWS configurations
  # return: (AWS Bucket object)
  def bucket
    @bucket ||= lambda{
      config = Aws.config.update({ region: @current_site.get_option("filesystem_region", 'us-west-2'), credentials: Aws::Credentials.new(@current_site.get_option("filesystem_s3_access_key"), @current_site.get_option("filesystem_s3_secret_key")) })
      s3 = Aws::S3::Resource.new
      bucket = s3.bucket(@current_site.get_option("filesystem_s3_bucket_name"))
    }.call
  end
end