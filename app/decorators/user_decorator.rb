=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class UserDecorator < ApplicationDecorator
  include CustomFieldsConcern
  delegate_all

  # return the identifier
  def the_username
    object.username
  end

  # return the fullname
  def the_name
    object.fullname
  end

  # return the role title of this user for current site
  def the_role
    object.get_role(h.current_site).name.titleize
  end

  # return the avatar for this user, default: assets/admin/img/no_image.jpg
  def the_avatar
    avatar_exists = File.exist? h.url_to_file_path(object.meta[:avatar])
    if object.meta[:avatar].present? && avatar_exists
      object.meta[:avatar]
    else
      h.asset_url("admin/img/no_image.jpg")
    end
  end

  # return the slogan for this user, default: Hello World
  def the_slogan
    object.meta[:slogan] || "Hello World"
  end

  # generate all seo attributes for profile page
  def the_seo
    h.build_seo({ image: (the_avatar rescue nil), title: the_name, object: self })
  end

  # return front url for this user
  def the_url(*args)
    args = args.extract_options!
    args[:user_id] = the_id
    args[:user_name] = the_name.parameterize
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.url_to_fixed("profile_#{as_path.present? ? "path" : "url"}", args)
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
