class Hash
  # convert hash to string like class="class val" name='name val'
  def to_attr_format(split = " ")
    res = []
    self.each do |key, value|
      res << "#{key} = \"#{value.to_s.gsub('"', '\"')}\""
    end
    res.join(split)
  end

  # convert hash to attributes for url_path
  def to_attr_url_format
    res = []
    self.each do |key, value|
      res << ":#{key} => \"#{value.to_s.gsub('"', '\"')}\""
    end
    res.join ","
  end

  # used for hash of objects
  def find_by(val, attr = "id")
    self.each do |key, p|
      if p[attr].to_s == val.to_s
        return p
      end
    end
    nil
  end

  def to_sym
    symbolize(self)
  end

  private
  def symbolize(obj)
    return obj.inject({}){|memo,(k,v)| memo[k.to_sym] =  symbolize(v); memo} if obj.is_a? Hash
    return obj.inject([]){|memo,v    | memo           << symbolize(v); memo} if obj.is_a? Array
    return obj
  end

end