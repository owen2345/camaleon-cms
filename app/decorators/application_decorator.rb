class ApplicationDecorator < Draper::Decorator
  delegate_all
  @_deco_locale = nil
  include MetasDecoratorMethods

  # return the keywords for this model
  def the_keywords
    k = object.get_option("keywords", "")
    k = h.current_site.the_keywords if object.class.name != "Site" && !k.present?
    k.translate(@_deco_locale)
  end

  def the_slug
    object.slug.translate(@_deco_locale)
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

  # internal helper
  def _calc_locale(_l)
    _l = (_l || @_deco_locale || I18n.locale).to_s
    "_#{_l}" if _l != "en"
  end
end
