class CamaleonCmsLocalUploader < CamaleonCmsUploader
  def after_initialize
    @root_folder = @args[:root_folder] || @current_site.upload_directory

    FileUtils.mkdir_p(@root_folder)
  end

  def setup_private_folder
    @root_folder = Rails.root.join(self.class::PRIVATE_DIRECTORY).to_s

    FileUtils.mkdir_p(@root_folder) unless Dir.exist?(@root_folder)
  end

  def browser_files(prefix = '/', objects = {})
    path = File.join(@root_folder, prefix)

    Dir.entries(path).each do |f_name|
      next if f_name == '..' || f_name == '.' || f_name == 'thumb'

      obj = file_parse(File.join(path, f_name).sub(@root_folder, '').cama_fix_media_key)
      cache_item(obj)

      if obj['is_folder']
        browser_files(File.join(prefix, obj['name']))
      end
    end
  end

  def fetch_file(file_name)
    if file_exists?(file_name)
      file_name
    else
      raise ActionController::RoutingError, 'File not found'
    end
  end

  def file_parse(key)
    file_path = File.join(@root_folder, key)
    url_path, is_dir = file_path.sub(Rails.root.join('public').to_s, ''), File.directory?(file_path)
    res = {
        "name" => File.basename(key),
        "folder_path" => File.dirname(key),
        "url" => is_dir ? '' : (is_private_uploader? ? url_path.sub("#{@root_folder}/", '') : File.join(@current_site.decorate.the_url(as_path: true, locale: false, skip_relative_url_root: true), url_path)),
        "is_folder" => is_dir,
        "file_size" => is_dir ? 0 : File.size(file_path).round(2),
        "thumb" => '',
        'file_type' => self.class.get_file_format(file_path),
        'dimension' => ''
    }.with_indifferent_access
    res['key'] = File.join(res['folder_path'], res['name'])
    res["thumb"] = (is_private_uploader? ? '/admin/media/download_private_file?file=' + version_path(key).slice(1..-1) : version_path(res['url'])) if res['file_type'] == 'image' && File.extname(file_path).downcase != '.gif'
    if res['file_type'] == 'image'
      res["thumb"].sub! '.svg', '.jpg'
      im = MiniMagick::Image.open(file_path)
      res['dimension'] = "#{im[:width]}x#{im[:height]}"
    end
    res
  end

  # save a file into local folder
  def add_file(uploaded_io_or_file_path, key, args = {})
    args, res = {same_name: false, is_thumb: false}.merge(args), nil
    key = search_new_key(key) unless args[:same_name]

    if @instance # private hook to upload files by different way, add file data into result_data
      _args={result_data: nil, file: uploaded_io_or_file_path, key: key, args: args, klass: self}; @instance.hooks_run('uploader_local_before_upload', _args)
      return _args[:result_data] if _args[:result_data].present?
    end

    add_folder(File.dirname(key)) if File.dirname(key).present?
    upload_io = uploaded_io_or_file_path.is_a?(String) ? File.open(uploaded_io_or_file_path) : uploaded_io_or_file_path
    File.open(File.join(@root_folder, key), 'wb'){|file|       file.write(upload_io.read) }
    res = cache_item(file_parse(key)) unless args[:is_thumb]
    res
  end

  # create a new folder into local directory
  def add_folder(key)
    d, is_new_folder = File.join(@root_folder, key).to_s, false
    unless Dir.exist?(d)
      FileUtils.mkdir_p(d)
      is_new_folder = true if File.basename(d) != 'thumb'
    end
    f = file_parse(key)
    cache_item(f) if is_new_folder
    f
  end

  # remove an existent folder
  def delete_folder(key)
    folder = File.join(@root_folder, key)
    FileUtils.rm_rf(folder) if Dir.exist? folder
    get_media_collection.find_by_key(key).take.destroy
  end

  # remove an existent file
  def delete_file(key)
    file = File.join(@root_folder, key)
    FileUtils.rm(file) if File.exist? file
    @instance.hooks_run('after_delete', key)
    get_media_collection.find_by_key(key).take.destroy
  end

  # convert a real file path into file key
  def parse_key(file_path)
    file_path.sub(@root_folder, '').cama_fix_media_key
  end
end
