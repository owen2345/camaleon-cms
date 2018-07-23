class CamaleonCmsUploader
  PRIVATE_DIRECTORY = 'private'
  
  attr_accessor :thumb
  # root_folder= '/var/www/my_public_foler/', current_site= CamaSite.first.decorate, thumb = {w: 100, h: 75},
  # aws_settings: {region, access_key, secret_key, bucket}
  def initialize(args = {}, instance = nil)
    @current_site = args[:current_site]
    t_w, t_h = @current_site.get_option('filesystem_thumb_size', '100x100').split('x')
    @thumb = args[:thumb] || {w: t_w, h: t_h}
    @aws_settings = args[:aws_settings] || {}
    @args = args
    @instance = instance
    after_initialize
  end

  def after_initialize

  end

  # load media files from a specific folder path
  def objects(prefix = '/', sort = 'created_at')
    prefix = prefix.cama_fix_media_key
    browser_files unless get_media_collection.any?
    res = ['/', ''].include?(prefix) ? get_media_collection.where(folder_path: '/') : get_media_collection.find_by_key(prefix).take.try(:items)
    # Private hook to recover custom files to include in current list where data can be modified to add custom{files, folders}
    # Note: this hooks doesn't have access to public vars like params. requests, ...
    if @instance
      args={data: res, prefix: prefix}; @instance.hooks_run('uploader_list_objects', args)
      res = args[:data]
    end
    res
  end

  # clean cached of files structure saved into DB
  def clear_cache
    get_media_collection.destroy_all
  end

  # search for folders or files that includes search_text in their names
  def search(search_text)
    get_media_collection.search(search_text)
  end

  # reload cache files structure
  def reload
    browser_files
  end

  # save file_parsed as a cache into DB
  # file_parsed: (HASH) File parsed object
  # objects_db: HASH Object where to add the current object (optional)
  def cache_item(file_parsed, _objects_db = nil, custom_cache_key = nil)
    unless get_media_collection.where(name: file_parsed['name'], folder_path: file_parsed['folder_path']).any?
      a = get_media_collection.new(file_parsed.except('key'))
      a.save!
    end
    file_parsed
  end

  # return the media collection for current situation
  def get_media_collection
    is_private_uploader? ? @current_site.public_media : @current_site.private_media
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
                  "jpg,jpeg,png,gif,bmp,ico,svg"
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
    valid_formats.include?(File.extname(key).sub(".", "").split('?').first.try(:downcase))
  end


  # verify if this file name already exist
  # if the file is already exist, return a new name for this file
  # sample: search_new_key("my_file/file.txt")
  def search_new_key(key)
    _key = key
    if get_media_collection.find_by_key(key).any?
      (1..999).each do |i|
        _key = key.cama_add_postfix_file_name("_#{i}")
        break unless get_media_collection.find_by_key(_key).any?
      end
    end
    _key
  end

  # check if file with :key exist and return parsed_file, else return nil
  def get_file(key, use_cache = true)
    # deprecated
  end

  def enable_private_mode!
    @args[:private] = true

    setup_private_folder
  end

  def disable_private_mode!
    @args[:private] = false
  end

  def file_exists?(file_name)
    File.exist?(file_name)
  end

  private
  def cache_key
    "cama_media_cache#{'_private' if is_private_uploader?}"
  end

  # check if this uploader is private mode
  def is_private_uploader?
    @args[:private]
  end
end
