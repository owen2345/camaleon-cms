module FileSystemHelper
  require 'fog'
  require 'aws-sdk'

  #file systems...  :s3, :local = default
  def is_local_filesystem
    init
    @file_system_type == :local
  end

  def list_files(path, pwd, only_folders=false, mimeFilter=nil)
    init
    format_media_path(path, pwd)
    init_storage(@media_path)
    if @file_system_type == :s3
      result = generate_tree_meta(only_folders, mimeFilter)
    else
      result = generate_directories_meta
      result = result + generate_files_meta(mimeFilter) unless only_folders
    end
    result
  end

  def add_folder(path, pwd, name)
    init
    format_media_path("/#{path}", pwd)
    init_storage(@media_path)
    if @file_system_type == :s3
      key = "#{@bucket}/#{@media_path}#{name}"
    else
      key = "#{name}"
    end
    @connection.directories.create(:key => key, :public => true)
    {succes: true, error: nil}
  end

  def delete(path, pwd, isDirectory = false)
    begin
      init
      format_media_path(path, pwd)
      init_storage(@local_root)
      if @file_system_type == :s3
        key_to_delete = isDirectory ? @media_path : @media_path[0..-2] #Remove the last / only in files
        @connection.delete_object(@bucket, key_to_delete)
        #TODO if @media_path is a directory and contains more files, this method do not delete the directory and no error is thrown out
      else
        if isDirectory
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

  def rename(path, pwd, new_path)
    begin
      init
      format_media_path(path, pwd)
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

  def copy(path, pwd, new_path)
    begin
      init
      format_media_path(path, pwd)
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

  def upload_files(destination, pwd, files)
    init
    format_media_path(destination, pwd)
    init_storage(@local_root)
    if @file_system_type == :s3
      folder = @connection.directories.get(@bucket)
      files.each do |file|
        filename_key = "#{@media_path}#{file.original_filename}"
        folder.files.new({:key => filename_key, :body => file.tempfile.open(), :public => true}).save
      end
    else
      folder = @connection.directories.get(destination)
      folder = @connection.directories.create(:key => destination) if folder.nil?
      files.each do |file|
        folder.files.new({:key => file.original_filename, :body => file.tempfile.open(), :public => true}).save
      end
    end
    {succes: true, error: nil}
  end

  def upload_image_file(image, destination)
    path = destination.gsub(root_filesystem_public_url, '')
    filename = path.split('/')[-1]
    directory = path.gsub(filename, '')
    init
    format_media_path(directory, nil)
    init_storage(@local_root)
    if @file_system_type == :s3
      filename_key = "#{@media_path}#{filename}"
      folder = @connection.directories.get(@bucket)
      folder.files.new({:key => filename_key, :body => image.to_blob, :public => true}).save
    else
      folder = @connection.directories.get(directory)
      folder = @connection.directories.create(:key => directory) if folder.nil?
      folder.files.new({:key => filename, :body => image.to_blob, :public => true}).save
    end
    {succes: true, error: nil}
  end

  def obtain_external_url(path, pwd, preview = false)
    init
    format_media_path(path, pwd)
    if path[0] == '/'
      root_filesystem_public_url + path
    else
      root_filesystem_public_url + '/' + path
    end
  end

  def root_filesystem_public_url
    init
    if @file_system_type == :s3
      @cdn_url.nil? ? "https://s3.amazonaws.com/#{@bucket}/media/#{current_site.id}" : "#{@cdn_url}/media/#{current_site.id}"
    else
      root_url + "media/#{current_site.id}"
    end
  end

  def current_user_pwd
    "/_users/#{current_user.id}"
  end

  def file_exists_by_url?(url_file)
    init
    if @file_system_type == :s3
      true
    else
      File.exist? h.url_to_file_path(url_file)
    end
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
          unless filename[-1] == '/' || filename.length == 0
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
        unless folder.prefix == '' || folder.prefix == @media_path || folder.prefix == '/'
          folder_name = folder.prefix.split('/').last
          tree_metas << {
              :name => folder_name,
              :ights => 'drwxr-xr-x',
              :size => '4096',
              :date => '2015-04-29 09:04:24',
              :type => 'dir'
          } unless private_folder?(folder_name)
        end
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
        } unless private_folder?(directory.key)
      end
    end
    directory_metas
  end

  def generate_files_meta(mimeFilter = nil)
    files_metas = []
    if @file_system_type == :local
      directory = @connection.directories.get('.')
      unless (directory.nil?)
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
    end
    files_metas
  end

  def format_media_path(path, pwd)
    if @file_system_type == :s3
      path = "#{path}/" unless path[-1] == '/'
      @media_path = (pwd.nil? || pwd.eql?('/')) ? "#{base_path}#{path}" : "#{base_path}#{pwd}#{path}"
      @local_root = base_path
    else
      @local_root = "#{base_path}"
      @media_path = pwd.nil? ? File.join(@local_root, path) : File.join(@local_root, pwd, path)
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
      #TODO put valid endpoint
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

  def private_folder?(folder_name)
    folder_name.eql?('_users')
  end

end