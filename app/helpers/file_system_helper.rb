module FileSystemHelper
  require 'fog'

  #file systems...  :s3, :local = default
  def is_local_filesystem
    init
    @file_system_type == :local
  end

  def list_files(path, only_folders=false)
    init
    format_media_path(path)
    init_storage(@media_path)
    if @file_system_type == :s3
      result = generate_tree_meta(only_folders)
    else
      result = generate_directories_meta
      result + generate_files_meta unless only_folders
    end
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
    if @file_system_type == :s3
      @cdn_url.nil? ? "https://s3.amazonaws.com/#{@bucket}/#{base_path}#{path}" : "#{@cdn_url}#{base_path}#{path}"
    else
      preview ? "/media/#{current_site.id}#{path}" : @media_path
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

  def generate_tree_meta(only_folders=false)
    tree_metas = []
    if @file_system_type == :s3
      media_path_size = @media_path.length
      files = @connection.directories.get(@bucket, {:prefix => @media_path, :delimiter => '/'}).files
      files.each do |file|
        tree_metas << {
            name: file.key[media_path_size..-1],
            rights: "drwxr-xr-x",
            size: "4096",
            date: "2015-04-29 09:04:24",
            type: "file"
        } unless file.key.length == media_path_size || file.key[-1] == '/' || only_folders
      end
      files.common_prefixes.each do |folder|
        tree_metas << {
            name: folder[media_path_size..-2],
            rights: "drwxr-xr-x",
            size: "4096",
            date: "2015-04-29 09:04:24",
            type: "dir"
        } unless folder.length == media_path_size
      end
    end
    tree_metas
  end

  def generate_directories_meta
    directory_metas = []
    if @file_system_type == :local
      @connection.directories.each do |directory|
        directory_metas << {
            name: directory.key,
            "rights": "drwxr-xr-x",
            "size": "4096",
            "date": "2015-04-29 09:04:24",
            type: "dir"
        }
      end
    end
    directory_metas
  end

  def generate_files_meta
    files_metas = []
    if @file_system_type == :local
      directory = @connection.directories.get('.')
      directory.files.each do |file|
        unless file.key.include? '/'
          files_metas << {
              name: file.key,
              "rights": "-rw-r--r--",
              "size": "549923",
              "date": "2013-11-01 11:44:13",
              type: "file"
          }
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
    else
      endpoint = 'http://camaleon-site:3000'
      @connection = Fog::Storage.new({:provider => 'Local', :local_root => local_root, :endpoint => endpoint})
    end
  end
end