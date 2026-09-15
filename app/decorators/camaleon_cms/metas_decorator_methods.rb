module CamaleonCms
  module MetasDecoratorMethods
    # The meta value for key in this model: a String read through the locale; an Array item by item, each
    # item read as a String through the locale whatever it holds, so a number or a boolean in it reads as a
    # String; and a value stored as a number, a boolean or a hash, which the locale cannot apply to, as read
    def the_meta(key)
      translate_read(object.get_meta(key, ''))
    end

    # The option value for key in this model, read the same way
    def the_option(key)
      translate_read(object.get_option(key, ''))
    end

    private

    def translate_read(value)
      value.is_a?(String) || value.is_a?(Array) ? value.translate(@_deco_locale) : value
    end
  end
end
