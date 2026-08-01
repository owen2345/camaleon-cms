require 'cgi'

class Hash
  # Attribute names are emitted verbatim, so they are restricted to a conservative subset of what
  # HTML allows rather than escaped: escaping cannot help here, because the characters that turn one
  # name into two (whitespace, `=`, `/`, quotes) are not HTML metacharacters. Covers the forms
  # actually used - `id`, `class`, `data-*`, `aria-*`, `xml:lang`.
  CAMA_HTML_ATTR_NAME = /\A[a-zA-Z_:][-a-zA-Z0-9_:.]*\z/

  # convert hash to string like class="class val" name='name val'
  #
  # Values are escaped for the HTML attribute context, so no value can close its own attribute and
  # introduce another. `CGI.escapeHTML` is used rather than `ERB::Util.html_escape` deliberately: the
  # latter is a no-op on an `html_safe` value, which would let a caller pass a string whose quote
  # survives into the output. Callers of this method are building attribute values, never markup, so
  # unconditional escaping is the correct contract.
  #
  # Pairs whose key is not a valid attribute name are dropped. A key such as `x onfocus=alert(1) y`
  # would otherwise render as three attributes, so there is no safe way to emit it; anything with a
  # space in it was already producing malformed markup before this guard existed.
  def to_attr_format(split = ' ')
    res = []
    each do |key, value|
      next unless key.to_s.match?(CAMA_HTML_ATTR_NAME)

      res << "#{key} = \"#{CGI.escapeHTML(value.to_s)}\""
    end
    res.join(split)
  end

  # convert hash to attributes for url_path
  #
  # Emits a Ruby fragment (`:key => "value"`) for code generation, not HTML, so it must NOT use the
  # HTML escaper above — entity-encoding would corrupt the generated code. `inspect` produces a
  # complete, correctly escaped double-quoted literal; the previous hand-rolled escape handled the
  # quote but not the backslash, so a value like `a\b` became a backspace and `a\"b` produced a
  # fragment that would not parse.
  def to_attr_url_format
    res = []
    each do |key, value|
      res << ":#{key} => #{value.to_s.inspect}"
    end
    res.join ','
  end

  # used for hash of objects
  def find_by(val, attr = 'id')
    each_value do |p|
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
