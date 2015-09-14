=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CustomFieldDecorator < Draper::Decorator
  delegate_all

  def the_name
    object.name.start_with?('t(')? eval(object.name.sub('t(', 'I18n.t(')) : object.name
  end
  def the_description
    if object.description.start_with?('t(')
      eval(object.description.sub('t(', 'I18n.t('))
    elsif object.description.start_with?('eval(')
      eval(object.description)
    else
      object.description
    end
  end

  # cache identifier, the format is: [current-site-prefix]/[object-id]-[object-last_updated]/[current locale]
  # key: additional key for the model
  def cache_prefix(key = "")
    "#{h.current_site.cache_prefix}/cfield#{object.id}#{"/#{key}" if key.present?}"
  end
end
