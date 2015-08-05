=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Themes::Default::DefaultHelper
  def self.included(klass)
    klass.helper_method [:get_taxonomy] rescue ""
  end

  def theme_default_load_app

  end

  def theme_default_settings(theme)

  end

  def get_taxonomy(taxonomies = {}, rel = '')
    list = []
    if taxonomies.present?
      taxonomies.each do |taxonomy|
        list << "<a href='#{taxonomy.the_url}' rel='#{rel}'>#{taxonomy.the_title}</a>"
      end
    end
    list.join(', ')
  end

  def theme_default_on_install(theme)
    theme.add_field({"name"=>"Footer message", "slug"=>"footer"},{field_key: "editor", default_value: 'Copyright &copy; 2015 - Camaleon CMS. All rights reservated.'})
  end

end