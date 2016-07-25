class CamaleonCmsLocalUploader < CamaleonCmsUploader
  PRIVATE_DIRECTORY = 'private'
  def browser_files(prefix = '/', objects = {})
    objects[prefix] = {files: {}, folders: {}}
    path = File.join(@root_folder, prefix)
    Dir.entries(path).each do |f_name|
      next if f_name == '..' || f_name == '.' || f_name == 'thumb'
      f_path = File.join(path, f_name)
      key = parse_key(f_path)
      obj = get_file(key) || file_parse(key)
      cache_item(obj, objects)
      browser_files(File.join(prefix, obj['name']), objects) if obj['format'] == 'folder'
    end
    @current_site.set_meta(cache_key, objects) if prefix == '/'
    objects
  end

  # return the full file path for private file with key
  # sample: 'my_file.pdf' ==> /var/www/my_app/private/my_file.pdf
  def self.private_file_path(key, current_site)
    Rails.root.join(self::PRIVATE_DIRECTORY, current_site.id.to_s, key.gsub(/(\/){2,}/, "/")).to_s
  end

  # check if this uploader is private mode
  def is_private_uploader?
    @args[:private]
  end

  def after_initialize
    if is_private_uploader?
      @root_folder = Rails.root.join(self.class::PRIVATE_DIRECTORY, @current_site.id.to_s).to_s
    else
      @root_folder = @args[:root_folder] || @current_site.upload_directory
    end
    FileUtils.mkdir_p(@root_folder) unless Dir.exist?(@root_folder)
  end

  def file_parse(key)
    file_path = File.join(@root_folder, key)
    url_path, is_dir = file_path.sub(Rails.root.join('public').to_s, ''), File.directory?(file_path)
    res = {
        "name" => File.basename(file_path),
        "key" => parse_key(file_path),
        "url" => is_dir ? '' : (is_private_uploader? ? url_path.sub("#{@root_folder}/", '') : File.join(@current_site.decorate.the_url(locale: false), url_path)),
        "is_folder" => is_dir,
        "size" => is_dir ? 0 : File.size(file_path).round(2),
        "format" => is_dir ? 'folder' : self.class.get_file_format(file_path),
        "deleteUrl" => '',
        "thumb" => '',
        'type' => (MIME::Types.type_for(file_path).first.content_type rescue ""),
        'created_at' => File.mtime(file_path),
        'dimension' => ''
    }.with_indifferent_access
    res["thumb"] = version_path(res['url']) if res['format'] == 'image' && File.extname(file_path).downcase != '.gif'
    if res['format'] == 'image'
      im = MiniMagick::Image.open(file_path)
      res['dimension'] = "#{im[:width]}x#{im[:height]}"
    end
    res
  end

  #
  def add_file(uploaded_io_or_file_path, key, args = {})
    args, res = {same_name: false, is_thumb: false}.merge(args), nil
    key = search_new_key(key) unless args[:same_name]
    add_folder(File.dirname(key)) if File.dirname(key).present?
    upload_io = uploaded_io_or_file_path.is_a?(String) ? File.open(uploaded_io_or_file_path) : uploaded_io_or_file_path
    File.open(File.join(@root_folder, key), 'wb'){|file|       file.write(upload_io.read) }
    res = cache_item(file_parse(key)) unless args[:is_thumb]
    res
  end

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

  def delete_folder(key)
    FileUtils.rm_rf(File.join(@root_folder, key))
    reload
  end

  def delete_file(key)
    FileUtils.rm(File.join(@root_folder, key))
    reload
  end

  # convert a real file path into file key
  def parse_key(file_path)
    r = file_path.sub(@root_folder, '')
    r = "/#{r}" unless r.starts_with?('/')
    r
  end
end