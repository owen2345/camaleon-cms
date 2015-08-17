=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class UserDecorator < Draper::Decorator
  include CustomFieldsConcern
  delegate_all

  # return the identifier
  def the_id
    "#{object.slug}"
  end

  # return the fullname
  def the_name
    object.fullname
  end

  # return the avatar for this user, default: assets/admin/img/no_image.jpg
  def the_avatar
     object.meta[:avatar].present? ? object.meta[:avatar] : h.asset_path("admin/img/no_image.jpg")
  end

  # return the slogan for this user, default: Hello World
  def the_slogan
    object.meta[:slogan] || "Hello World"
  end

  # return all contents created by this user in current site
  def the_contents
    h.current_site.posts.where(user_id: object.id)
  end

  # cache identifier, the format is: [current-site-prefix]/[object-id]-[object-last_updated]/[current locale]
  # key: additional key for the model
  def cache_prefix(key = "")
    "#{h.current_site.cache_prefix}/user#{object.id}#{"/#{key}" if key.present?}"
  end


end
