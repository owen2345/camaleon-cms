class String
  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.blank? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end

  def strip_tags
    ActionController::Base.helpers.strip_tags(self)
  end

  def is_email
    return false if self.blank?
    return /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/.match(self).present?
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

  def split_bar
    self.split(',').map{|us_id| us_id.gsub('__','')}.uniq
  end

  def include_bar?(uid)
    self.include?("__#{uid}__")
  end

  # slice string respect to correct word for read more
  def slice_read_more(quantity = 100, start_from = 0)
    return self if self.length <= quantity
    tmp = self.slice(start_from, self.length)
    if tmp.slice(quantity) == " " || tmp.index(" ").nil?
      return tmp.slice(0, quantity)
    end
    quantity += tmp.slice(quantity, tmp.length).index(" ").nil? ? tmp.length : tmp.slice(quantity, tmp.length).index(" ")
    tmp.slice(0, quantity)
  end

  # slice string respect to correct word for read more
  def truncate_text(string, quantity = 100, quantity_before_text = 20)
    string = string.gsub("+", "").gsub("*", "").gsub("-", "").downcase
    self.strip_tags
    return self if self.length <= quantity
    start_from = self.downcase.index("#{string}")
    start_from = self.index(/#{string.split(" ").join("|")}/i) unless start_from.present?
    start_from -= quantity_before_text  if start_from.present? && start_from > 0
    start_from = 0 if start_from.nil? || start_from < 0
    tmp = self.slice(start_from, self.length)
    if tmp.slice(quantity) == " " || tmp.index(" ").nil?
      return tmp.slice(0, quantity)
    end
    quantity += tmp.slice(quantity, tmp.length).to_s.index(" ").nil? ? tmp.length : tmp.slice(quantity, tmp.length).to_s.index(" ")
    tmp.slice(0, quantity)
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

  # from a string path, this function get the filename
  def get_file_name
    self.split("/").last.split(".").delete_last.join(".")
  end

  def hex_to_binary
    temp = gsub("\s", "");
    ret = []
    (0...temp.size()/2).each{|index| ret[index] = [temp[index*2, 2]].pack("H2")}
    return ret
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
  #  /var/www/media/132/logo.png ==> /var/www/media/132/logo_2.png
  def cama_add_postfix_file_name(postfix)
    File.join(File.dirname(self), "#{File.basename(self, File.extname(self))}#{postfix}#{File.extname(self)}")
  end

end