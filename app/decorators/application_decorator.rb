class ApplicationDecorator < Draper::Decorator
  delegate_all
  @_deco_locale = nil
  include MetasDecoratorMethods

  # return the keywords for this model
  def the_keywords
    k = object.get_option("keywords", "")
    k = h.current_site.the_keywords if object.class.name != "Site" && !k.present?
    k.translate(get_locale)
  end

  def the_slug
    object.slug.translate(get_locale)
  end

  # return the identifier
  def the_id
    "#{object.id}"
  end

  # return created at date formatted
  def the_created_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # return updated at date formatted
  def the_updated_at(format = :long)
    h.l(object.created_at, format: format.to_sym)
  end

  # draw breadcrumb for this model
  # add_post_type: true/false to include post type link
  def the_breadcrumb(add_post_type = true)
    generate_breadcrumb(add_post_type)
    h.breadcrumb_draw
  end

  # build the attributes for this model
  def the_seo
    h.build_seo({ image: (the_thumb_url() rescue nil), title: the_title, description: the_excerpt, keywords: the_keywords })
  end

  # ---------------------
  def set_decoration_locale(locale)
    @_deco_locale = locale.to_sym
  end

  # verify admin request to show the first language as the locale
  # if the request is not for frontend, then this will show current locale visited
  def get_locale(locale = nil)
    l = locale || @_deco_locale
    (h.is_admin_request? rescue false) ? h.current_site.get_languages.first : l
  end

  # internal helper
  def _calc_locale(_l)
    _l = (_l || @_deco_locale || I18n.locale).to_s
    "_#{_l}" if _l != "en"
  end

  # save a cache value
  # var_name: (string) cache var name
  # value: optional (nil => value getter if not value will be saved)
  # return value saved or recovered if value argument is nil
  def cache_var(var_name, value = nil)
    cache_key = "@cache_#{object.id}_#{object.class.name}_#{var_name}"
    cache = instance_variable_get(cache_key) rescue nil
    return cache if value.nil?
    instance_variable_set(cache_key, value)
    value
  end
end
