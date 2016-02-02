=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::UserDecorator < CamaleonCms::ApplicationDecorator
  include CamaleonCms::CustomFieldsConcern
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
    avatar_exists? ? object.get_meta("avatar") : h.asset_url("camaleon_cms/admin/img/no_image.jpg")
  end

  # return the slogan for this user, default: Hello World
  def the_slogan
    object.get_meta("slogan", "Hello World")
  end

  # return front url for this user
  def the_url(*args)
    args = args.extract_options!
    args[:user_id] = the_id
    args[:user_name] = the_name.parameterize
    args[:user_name] = the_username unless args[:user_name].present?
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.cama_url_to_fixed("cama_profile_#{as_path.present? ? "path" : "url"}", args)
  end

  # return the url for the profile in the admin module
  def the_admin_profile_url
    h.cama_admin_profile_url(object.id)
  end

  # return all contents created by this user in current site
  def the_contents
    h.current_site.posts.where(user_id: object.id)
  end

  private

  def avatar_exists?
    # TODO change verification
    # if object.get_meta('avatar').present?
    #   File.exist?(h.cama_url_to_file_path(object.get_meta('avatar'))) || Faraday.head(object.get_meta('avatar')).status == 200
    # else
    #   false
    # end
    object.get_meta('avatar').present?
  end
end
