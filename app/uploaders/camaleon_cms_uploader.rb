class CamaleonCmsUploader
  attr_accessor :thumb
  # root_folder= '/var/www/my_public_foler/', current_site= CamaSite.first.decorate, thumb = {w: 100, h: 75},
  # aws_settings: {region, access_key, secret_key, bucket}
  def initialize(args = {})
    @current_site = args[:current_site]
    t_w, t_h = @current_site.get_option('filesystem_thumb_size', '100x100').split('x')
    @thumb = args[:thumb] || {w: t_w, h: t_h}
    @aws_settings = args[:aws_settings] || {}
    @args = args
    after_initialize
  end

  def after_initialize

  end

  # return all files structure, within folder prefix
  # return json like:
  # {files: {'file_name': {'name'=> 'a.jpg', key: '/test/a.jpg', url: '', url: '', size: '', format: '', thumb: 'thumb_url', type: '', created_at: '', dimension: '120x120'}}, folders: {'folder name' => {name: 'folder name', key: '/folder name', ...}}}
  # sort: (String, default 'created_at'), accept for: created_at | name | size | type | format
  def objects(prefix = '/', sort = 'created_at')
    prefix = "/#{prefix}" unless prefix.starts_with?('/')
    db = @current_site.get_meta(cache_key, nil) || browser_files
    res = db[prefix.gsub('//', '/')] || {files: {}, folders: {}}
    res[:files] = res[:files].sort_by{|k, v| v[sort] }.reverse.to_h
    res[:folders] = res[:folders].sort_by{|k, v| v['name'] }.reverse.to_h
    res
  end

  # clean cached of files structure saved into DB
  def clear_cache
    @current_site.set_meta(cache_key, nil)
  end

  # search for folders or files that includes search_text in their names
  def search(search_text)
    res = {files: {}, folders: {}}
    (@current_site.get_meta(cache_key, nil) || browser_files).each do |folder_key, object|
      res[:folders][folder_key] = get_file(folder_key) if !['', '/'].include?(folder_key) && folder_key.split('/').last.include?(search_text)
      object[:files].each do |file_key, obj|
        res[:files][file_key] = obj if file_key.include?(search_text)
      end
      res
    end
    res
  end

  # reload cache files structure
  def reload
    browser_files
  end

  # save file_parsed as a cache into DB
  # file_parsed: (HASH) File parsed object
  # objects_db: HASH Object where to add the current object (optional)
  def cache_item(file_parsed, _objects_db = nil)
    objects_db = _objects_db || @current_site.get_meta(cache_key, {}) || {}
    prefix = File.dirname(file_parsed['key'])

    s = prefix.split('/').clean_empty
    return file_parsed if s.last == 'thumb'
    s.each_with_index{|_s, i| k = "/#{File.join(s.slice(0, i), _s)}".cama_fix_slash; cache_item(file_parse(k), objects_db) unless objects_db[k].present? } unless ['/', '', '.'].include?(prefix)

    objects_db[prefix] = {files: {}, folders: {}} if objects_db[prefix].nil?
    if file_parsed['format'] == 'folder'
      objects_db[prefix][:folders][file_parsed['name']] = file_parsed
    else
      objects_db[prefix][:files][file_parsed['name']] = file_parsed
    end
    @current_site.set_meta(cache_key, objects_db) if _objects_db.nil?
    file_parsed
  end


  # convert current string path into file version_path, sample:
  # version_path('/media/1/screen.png') into /media/1/thumb/screen-png.png (thumbs)
  # Sample: version_path('/media/1/screen.png', '200x200') ==> /media/1/thumb/screen-png_200x200.png (image versions)
  def version_path(image_path, version_name = nil)
    res = File.join(File.dirname(image_path), 'thumb', "#{File.basename(image_path).parameterize}#{File.extname(image_path)}")
    res = res.cama_add_postfix_file_name("_#{version_name}") if version_name.present?
    res
  end

  # return the file format (String) of path (depends of file extension)
  def self.get_file_format(path)
    ext = File.extname(path).sub(".", "").downcase
    format = "unknown"
    format = "image" if get_file_format_extensions('image').split(",").include?(ext)
    format = "video" if get_file_format_extensions('video').split(",").include?(ext)
    format = "audio" if get_file_format_extensions('audio').split(",").include?(ext)
    format = "document" if get_file_format_extensions('document').split(",").include?(ext)
    format = "compress" if get_file_format_extensions('compress').split(",").include?(ext)
    format
  end

  # return the files extensión for each format
  # support for multiples formats, sample: image,audio
  def self.get_file_format_extensions(format)
    res = []
    format.downcase.gsub(' ', '').split(',').each do |f|
      res << case f
                when 'image', 'images'
                  "jpg,jpeg,png,gif,bmp,ico"
                when 'video', 'videos'
                  "flv,webm,wmv,avi,swf,mp4,mov,mpg"
                when 'audio'
                  "mp3,ogg"
                when 'document', 'documents'
                  "pdf,xls,xlsx,doc,docx,ppt,pptx,html,txt,xml,json"
                when 'compress'
                  "zip,7z,rar,tar,bz2,gz,rar2"
                else
                  ''
              end
    end
    res.join(',')
  end

  # verify permitted formats (return boolean true | false)
  # true: if format is accepted
  # false: if format is not accepted
  # sample: validate_file_format('/var/www/myfile.xls', 'image,audio,docx,xls') => return true if the file extension is in formats
  def self.validate_file_format(key, valid_formats = "*")
    return true if valid_formats == "*" || !valid_formats.present?
    valid_formats = valid_formats.gsub(' ', '').downcase.split(',') + get_file_format_extensions(valid_formats).split(',')
    valid_formats.include?(File.extname(key).sub(".", "").split('?').first.downcase)
  end


  # verify if this file name already exist
  # if the file is already exist, return a new name for this file
  # sample: search_new_key("my_file/file.txt")
  def search_new_key(key)
    _key = key
    if get_file(key).present?
      (1..999).each do |i|
        _key = key.cama_add_postfix_file_name("_#{i}")
        break unless get_file(_key).present?
      end
    end
    _key
  end

  # check if file with :key exist and return parsed_file, else return nil
  def get_file(key, use_cache = true)
    if use_cache
      db = (@current_site.get_meta(cache_key) || {})[File.dirname(key)] || {}
    else
      db = objects(File.dirname(key)) unless use_cache
    end
    (db[:files][File.basename(key)] || db[:folders][File.basename(key)]) rescue nil
  end

  private
  def cache_key
    "cama_media_cache#{'_private' if is_private_uploader?}"
  end
  def is_private_uploader?() end

end
