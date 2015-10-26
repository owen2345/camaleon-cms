module FileSystemHelper
  require 'fog'
  require 'aws-sdk'

  #file systems...  :s3, :local = default
  def is_local_filesystem
    init
    @file_system_type == :local
  end

  def list_files(path, only_folders=false, mimeFilter=nil)
    init
    format_media_path(path)
    init_storage(@media_path)
    if @file_system_type == :s3
      result = generate_tree_meta(only_folders, mimeFilter)
    else
      result = generate_directories_meta
      result = result + generate_files_meta(mimeFilter) unless only_folders
    end
    result
  end

  def add_folder(path, name)
    init
    format_media_path("/#{path}")
    init_storage(@media_path)
    if @file_system_type == :s3
      key = "#{@bucket}/#{@media_path}#{name}"
    else
      key = "#{name}"
    end
    @connection.directories.create(:key => key, :public => true)
    {succes: true, error: nil}
  end

  def delete(path)
    begin
      init
      format_media_path(path)
      init_storage(@local_root)
      if @file_system_type == :s3
        @connection.delete_object(@bucket, @media_path)
        #TODO if @media_path is a directory and contains more files, this method not delete the directory and no error is thrown out
      else
        if File.directory?(@media_path)
          @connection.directories.get(path).destroy
        else
          file_basename = File.basename(@media_path)
          relative_path = path[0..-(file_basename.length+1)]
          folder = @connection.directories.get(relative_path)
          folder.files.get(file_basename).destroy
        end
      end
      {succes: true, error: nil}
    rescue Errno::ENOTEMPTY
      {succes: false, error: 'Directory not empty'}
    end
  end

  def rename(path, new_path)
    begin
      init
      format_media_path(path)
      init_storage(@local_root)
      if @file_system_type == :s3
        options = {'x-amz-acl' => 'public-read'}
        old_file = "#{base_path}#{path}"
        @connection.copy_object(@bucket, old_file, @bucket, "#{base_path}#{new_path}", options)
        @connection.delete_object(@bucket, old_file)
      else
        name_old_file = File.basename(path)
        name_new_file = File.basename(new_path)
        relative_path_old = path[0..-(name_old_file.length+1)]
        relative_path_new = new_path[0..-(name_new_file.length+1)]
        @connection.copy_object(relative_path_old, name_old_file, relative_path_new, name_new_file)
        @connection.directories.get(relative_path_new).files.get(name_old_file).destroy
      end
      {succes: true, error: nil}
    rescue Exception => exception
      {succes: false, error: exception.message}
    end
  end

  def copy(path, new_path)
    begin
      init
      format_media_path(path)
      init_storage(@local_root)
      if @file_system_type == :s3
        options = {'x-amz-acl' => 'public-read'}
        old_file = "#{base_path}#{path}"
        @connection.copy_object(@bucket, old_file, @bucket, "#{base_path}#{new_path}", options)
      else
        name_old_file = File.basename(path)
        name_new_file = File.basename(new_path)
        relative_path_old = path[0..-(name_old_file.length+1)]
        relative_path_new = new_path[0..-(name_new_file.length+1)]
        @connection.copy_object(relative_path_old, name_old_file, relative_path_new, name_new_file)
      end
      {succes: true, error: nil}
    rescue Exception => exception
      {succes: false, error: exception.message}
    end
  end

  def upload_files(destination, files)
    init
    format_media_path(destination)
    init_storage(@local_root)
    if @file_system_type == :s3
      folder = @connection.directories.get(@bucket)
      files.each do |file|
        folder.files.new({:key => "#{@media_path}#{file.original_filename}", :body => file.tempfile.open(), :public => true}).save
      end
    else
      folder = @connection.directories.get(destination)
      files.each do |file|
        folder.files.new({:key => file.original_filename, :body => file.tempfile.open(), :public => true}).save
      end
    end
    {succes: true, error: nil}
  end

  def obtain_external_url(path, preview = false)
    init
    format_media_path(path)
    root_filesystem_public_url + path
  end

  def root_filesystem_public_url
    init
    if @file_system_type == :s3
      @cdn_url.nil? ? "https://s3.amazonaws.com/#{@bucket}" : @cdn_url
    else
      root_url + "media/#{current_site.id}"
    end
  end

  def current_user_pwd
    "users/#{current_user.id}"
  end

  private

  def init
    if @file_system_type.nil?
      @file_system_type = current_site.the_option('filesystem_type').to_sym
      @file_system_type = :local if @file_system_type.nil? || @file_system_type.length < 2
      @aws_access_key_id = current_site.the_option('filesystem_s3_access_key')
      @aws_secret_key = current_site.the_option('filesystem_s3_secret_key')
      @bucket = current_site.the_option('filesystem_s3_bucket_name')
      @cdn_url = current_site.the_option('filesystem_cdn')
      @cdn_url = nil if @cdn_url.length < 2
    end
  end

  def generate_tree_meta(only_folders=false, mimeFilter = nil)
    tree_metas = []
    if @file_system_type == :s3
      media_path_size = @media_path.length
      query = {:bucket => @bucket, :delimiter => '/', :encoding_type => 'url', :max_keys => 100, :prefix => @media_path}
      response = @s3_client.list_objects(query)
      unless only_folders
        response.contents.each do |file|
          filename = file.key.gsub(@media_path, '')
          unless filename.length == media_path_size || filename[-1] == '/' || filename.length == 0
            tree_metas << {
                name: filename,
                rights: "drwxr-xr-x",
                size: "4096",
                date: "2015-04-29 09:04:24",
                type: "file"
            } if valid_mime_type?(mimeFilter, filename)
          end
        end
      end
      response.common_prefixes.each do |folder|
        tree_metas << {
            :name => folder.prefix.split('/').last,
            :ights => 'drwxr-xr-x',
            :size => '4096',
            :date => '2015-04-29 09:04:24',
            :type => 'dir'
        } unless folder.prefix == '' || folder.prefix == @media_path || folder.prefix == '/'
      end
    end
    tree_metas
  end

  def generate_directories_meta
    directory_metas = []
    if @file_system_type == :local
      @connection.directories.each do |directory|
        directory_metas << {
            :name => directory.key,
            :rights => 'drwxr-xr-x',
            :size => '4096',
            :date => '2015-04-29 09:04:24',
            :type => 'dir'
        }
      end
    end
    directory_metas
  end

  def generate_files_meta(mimeFilter = nil)
    files_metas = []
    if @file_system_type == :local
      directory = @connection.directories.get('.')
      directory.files.each do |file|
        unless file.key.include? '/'
          files_metas << {
              :name => file.key,
              :rights => '-rw-r--r--',
              :size => '549923',
              :date => '2013-11-01 11:44:13',
              :type => 'file'
          } if valid_mime_type?(mimeFilter, file.key)
        end
      end
    end
    files_metas
  end

  def format_media_path(path)
    if @file_system_type == :s3
      path = "#{path}/" unless path[-1] == '/'
      @media_path = "#{base_path}#{path}"
      @local_root = base_path
    else
      @local_root = "#{base_path}"
      @media_path = File.join(@local_root, path)
    end
  end

  def base_path
    if @file_system_type == :s3
      "media/#{current_site.id}"
    else
      File.join(Rails.public_path, "/media/#{current_site.id}")
    end
  end

  def init_storage(local_root)
    if @file_system_type == :s3
      @connection = Fog::Storage.new({:provider => 'AWS', :aws_access_key_id => @aws_access_key_id, :aws_secret_access_key => @aws_secret_key})
      Aws.config.update({:region => 'us-east-1', :credentials => Aws::Credentials.new(@aws_access_key_id, @aws_secret_key)})
      @s3_client = Aws::S3::Client.new
    else
      endpoint = 'http://camaleon-site:3000'
      @connection = Fog::Storage.new({:provider => 'Local', :local_root => local_root, :endpoint => endpoint})
    end
  end

  def valid_mime_type?(mimetype, filename)
    unless mimetype.nil?
      case mimetype.to_s.to_sym
        when :none
          true
        when :images
          (filename =~ /\.(jpe?g|gif|bmp|png|svg|tiff?)$/i) != nil
        else
          false
      end
    else
      true
    end
  end

end