class String

  # return translation value of locale
  # if locale is nil, it will use I18n.locale

  # Usage
  # The default value if translation is not provided is all text
  #
  #  $ WpPost.post_title
  #  $ => "<!--:en-->And this is how the Universe ended.<!--:--><!--:fr-->Et c'est ainsi que l'univers connu cessa d'exister.<!--:-->"
  #  $ I18n.locale = :en
  #  $ WpPost.post_title.translate
  #  $ => "And this is how the Universe ended."
  #  $ WpPost.post_title.translate(:en)
  #  $ => "And this is how the Universe ended."
  #
  #  Spits the same text out if no translation tags are applied
  #  $ WpPost.post_title
  #  $ => "And this is how the Universe ended."
  #  $ WpPost.post_title.translate(:fr)
  #  $ => "And this is how the Universe ended."

  def translate(locale = nil)
    locale ||= I18n.locale
    locale = locale.to_sym
    return self if !self.squish.starts_with?("<!--") or self.blank?
    return translations[locale] if translations.has_key?(locale)
    return translations[I18n.default_locale] if translations.has_key?(I18n.default_locale)
    return '' if translations.keys.any?
    self
  end

  # return hash of translations for this string
  # sample: {es: "hola mundo", en: "Hello World"}
  def translations
    @translations ||= split_locales
    @translations
  end

  # return aray of translations for this string
  # sample: ["hola mundo", "Hello World"]
  def translations_array
    r = translations.map{|key, value| value}
    return r.present? ? r : [self]
  end

  protected
  def split_locales
    translations_per_locale = {}
    return translations_per_locale if !self.squish.starts_with?("<!--") or self.blank?

    self.split('<!--:-->').each do |t|
      t.match(/^<!--:([\w||-]{2,5})/) do |lang|
        lt = lang[1].sub("--", "")
        translations_per_locale[lt.to_sym] = t.gsub(/<!--:#{lt}-->(.*)/, '\1')
      end
    end
    translations_per_locale
  end
end


class Hash
  # convert hash to translation string structure
  # sample: {es: "hola mundo", en: "Hello World"}
  # ==> <!--:es-->Hola Mundo<!--:--><!--:en-->Hello World<!--:-->
  def to_translate
    res = []
    self.each do|key, val|
      res << "<!--:#{key}-->#{val}<!--:-->"
    end
    res.join("")
  end
end

class Array
  # translate array values
  # return the same array translated
  def translate(locale = nil)
    self.collect do |val|
      val.to_s.translate(locale)
    end
  end
end
