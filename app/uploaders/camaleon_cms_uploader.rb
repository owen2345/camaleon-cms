class CamaleonCmsUploader
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

  def self.folder_path(key)
    split_folder = key.split('/').reject(&:empty?)
    split_folder.pop
    '/' + split_folder.join('/')
  end

  # leaves only a-z 0-9 - _ characters
  def self.slugify(val)
    val.to_s.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end

  # leaves only a-z 0-9 - _ . characters
  def self.slugify_file(val)
    val.to_s.downcase.strip.gsub(' ', '-').gsub(/[^\w.-]/, '')
  end

  # certify that user doesn't create strange folder names
  def self.slugify_folder(val)
    splitted_folder = val.split('/')
    splitted_folder[-1] = slugify(splitted_folder.last)
    splitted_folder.join('/')
  end

  def self.thumbnail(url)
    # replace extension
    splitted = url.split('.')
    extension = "-#{splitted.last}.#{splitted.last}"
    splitted.pop
    splitted[splitted.length-1] = splitted[splitted.length - 1] + extension
    result = splitted.join('.')

    # add thumb folder to structure
    splitted = result.split('/')
    splitted.insert(splitted.count-1, 'thumb') # add thumb
    splitted[splitted.count-1] = splitted[splitted.count-1].downcase # convert to downcase
    splitted.join('/')
  end

  # verify permitted formats (return boolean true | false)
  # true: if format is accepted
  # false: if format is not accepted
  # sample: validate_file_format('/var/www/myfile.xls', 'image,audio,docx,xls') => return true if the file extension is in formats
  def self.validate_file_format(key, valid_formats = "*")
    return true if valid_formats == "*" || valid_formats.blank?
    valid_formats = valid_formats.delete(' ').downcase.split(',') + get_file_format_extensions(valid_formats).split(',')
    valid_formats.include?(File.extname(key).sub(".", "").split('?').first.try(:downcase))
  end


  private

  def cache_key
    "cama_media_cache#{'_private' if is_private_uploader?}"
  end

  def is_private_uploader?; end

end
