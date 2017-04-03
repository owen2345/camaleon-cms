class CamaleonCms::ApplicationDecorator < Draper::Decorator
  delegate_all
  @_deco_locale = nil
  include CamaleonCms::MetasDecoratorMethods

  # return the keywords for this model
  def the_keywords
    k = object.get_option("keywords", "")
    k = h.current_site.the_keywords if object.class.name != "CamaleonCms::Site" && !k.present?
    k.to_s.translate(get_locale)
  end

  def the_slug(locale = nil)
    object.slug.translate(get_locale(locale))
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

  # ---------------------
  def set_decoration_locale(locale)
    @_deco_locale = locale.to_sym
  end

  # get the locale for current decorator
  def get_locale(locale = nil)
    locale || @_deco_locale || (h.cama_get_i18n_frontend rescue nil) || I18n.locale
  end

  # return the current locale prefixed to add in frontend routes
  def _calc_locale(_l)
    _l = (_l || @_deco_locale || (h.cama_get_i18n_frontend rescue nil) || I18n.locale).to_s
    "_#{_l}"
  end
end
