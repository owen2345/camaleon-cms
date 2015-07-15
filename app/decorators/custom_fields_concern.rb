module CustomFieldsConcern
  # ======================CUSTOM FIELDS=====================================
  # render as html the custom fields marked for frontend
  def render_fields
    r = cache_var("render_fields") || h.controller.render_to_string(partial: "partials/render_custom_field", :locals => {fields: object.get_fields_object(true)})
    cache_var("render_fields", r)
  end

  # return custom field content with key field_key
  # translated and short codes evaluated like the content
  def the_field(field_key)
    h.do_shortcode(object.get_field_value(field_key).to_s.translate(@_deco_locale), object)
  end

  # return custom field contents with key field_key
  # translated and short codes evaluated like the content
  # this is for multiple values
  def the_fields(field_key)
    r = []
    object.get_field_values(field_key).each do |text|
      r << h.do_shortcode(text.to_s.translate(@_deco_locale), object)
    end
    r
  end
end