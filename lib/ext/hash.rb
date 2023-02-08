class Hash
  # convert hash to string like class="class val" name='name val'
  def to_attr_format(split = ' ')
    res = []
    each do |key, value|
      res << "#{key} = \"#{value.to_s.gsub('"', '\"')}\""
    end
    res.join(split)
  end

  # convert hash to attributes for url_path
  def to_attr_url_format
    res = []
    each do |key, value|
      res << ":#{key} => \"#{value.to_s.gsub('"', '\"')}\""
    end
    res.join ','
  end

  # used for hash of objects
  def find_by(val, attr = 'id')
    each do |_key, p|
      return p if p[attr].to_s == val.to_s
    end
    nil
  end

  def to_sym
    symbolize(self)
  end

  private

  def symbolize(obj)
    if obj.is_a? Hash
      return obj.each_with_object({}) do |(k, v), memo|
               memo[k.to_sym] = symbolize(v)
             end
    end
    if obj.is_a? Array
      return obj.each_with_object([]) do |v, memo|
               memo << symbolize(v)
             end
    end

    obj
  end
end
