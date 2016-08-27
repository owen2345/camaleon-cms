class String
  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.blank? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end

  def strip_tags
    ActionController::Base.helpers.strip_tags(self)
  end

  def is_float?
    self.to_f.to_s == self.to_s
  end

  def is_number?
    self.to_f.to_s == self.to_s || self.to_i.to_s == self.to_s
  end

  def is_bool?
    self == 'false' || self == 'true'
  end

  # check if current string is true or false
  # cases for true: '1' | 'true'
  # cases for false: '0' | 'false' | ''
  # return boolean
  def cama_true?
    self == 'true' || self == '1'
  end

  def to_var
    if is_float?
      self.to_f
    elsif is_number?
      self.to_i
    elsif is_bool?
      self.to_bool
    else
      self
    end
  end

  # parse string into slug format
  def slug
    #strip the string
    ret = self.strip

    #blow away apostrophes
    ret.gsub! /['`]/,""

    # @ --> at, and & --> and
    ret.gsub! /\s*@\s*/, " at "
    ret.gsub! /\s*&\s*/, " and "

    #replace all non alphanumeric, underscore or periods with underscore
    ret.gsub! /\s*[^A-Za-z0-9\.\-]\s*/, '_'

    #convert double underscores to single
    ret.gsub! /_+/,"_"

    #strip off leading/trailing underscore
    ret.gsub! /\A[_\.]+|[_\.]+\z/,""
    ret
  end

  # parse string into domain
  # http://owem.tuzitio.com into owem.tuzitio.com
  def parse_domain
    url = self
    uri = URI.parse(url)
    uri = URI.parse("http://#{url}") if uri.scheme.nil?
    host = (uri.host || self).downcase
    h = host.start_with?('www.') ? host[4..-1] : host
    "#{h}#{":#{uri.port}" unless [80, 443].include?(uri.port)}"
  end

  # parse all codes in current text to replace with values
  # sample: "Hello [c1]".cama_replace_codes({c1: 'World'}) ==> Hello World
  def cama_replace_codes(values, format_code = '[')
    res = self
    values.each do |k, v|
      v = v.join(',') if v.is_a?(Array)
      res = res.gsub("[#{k}]", v) if format_code == '['
      res = res.gsub("{#{k}}", v) if format_code == '{'
    end
    res
  end

  # return cleaned model class name
  # remove decorate
  # remove Cama prefix
  def parseCamaClass
    self.gsub("Decorator","").gsub("CamaleonCms::","")
  end

  # convert url into custom url with postfix,
  # sample: "http://localhost/company/rack_multipart20160124_2288_8xcdjs.jpg".cama_add_postfix_url('thumbs/') into http://localhost/company/thumbs/rack_multipart20160124_2288_8xcdjs.jpg
  def cama_add_postfix_url(postfix)
    File.join(File.dirname(self), "#{postfix}#{File.basename(self)}")
  end

  # Sample:
  #  '/var/www/media/132/logo.png'.cama_add_postfix_file_name('_2') ==> /var/www/media/132/logo_2.png
  def cama_add_postfix_file_name(postfix)
    File.join(File.dirname(self), "#{File.basename(self, File.extname(self))}#{postfix}#{File.extname(self)}")
  end

  # Parse the url to get the image version
  #   version_name: (String) version name,
  #     if this is empty, this will return the image version for thumb of the image, sample: 'http://localhost/my_image.png'.cama_parse_image_version('') => http://localhost/thumb/my_image.png
  #     if this is present, this will return the image version generated, sample: , sample: 'http://localhost/my_image.png'.cama_parse_image_version('200x200') => http://localhost/thumb/my_image_200x200.png
  #   default: default image if post image does not exist
  def cama_parse_image_version(version_name = '')
    res = File.join(File.dirname(self), 'thumb', "#{File.basename(self).parameterize}#{File.extname(self)}")
    res = res.cama_add_postfix_file_name("_#{version_name}") if version_name.present?
    res
  end
end