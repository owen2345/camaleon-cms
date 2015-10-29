=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::CustomFieldsConcern
  # ======================CUSTOM FIELDS=====================================
  # render as html the custom fields marked for frontend
  def render_fields
    object.cama_fetch_cache("render_fields") do
      h.controller.render_to_string(partial: "partials/render_custom_field", :locals => {fields: object.get_fields_object(true)})
    end
  end

  # return custom field content with key field_key
  # translated and short codes evaluated like the content
  # default_val: default value returned when this field was not registered
  def the_field(field_key, default_val = '')
    h.do_shortcode(object.get_field(field_key, default_val).to_s.translate(@_deco_locale), object)
  end

  # the same as the_field(..), but this return default value if there is not present
  def the_field!(field_key, default_val = '')
    h.do_shortcode(object.get_field!(field_key, default_val).to_s.translate(@_deco_locale), object)
  end

  # return custom field contents with key field_key
  # translated and short codes evaluated like the content
  # this is for multiple values
  def the_fields(field_key)
    r = []
    object.get_fields(field_key).each do |text|
      r << h.do_shortcode(text.to_s.translate(@_deco_locale), object)
    end
    r
  end
end