=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::PostTypeDecorator < CamaleonCms::TermTaxonomyDecorator
  delegate_all

  # return the public url for this post type
  # Sample: http://localhost/my-group.html
  def the_url(*args)
    args = args.extract_options!
    args[:post_type_id] = the_id
    args[:post_type_slug] = I18n.t("routes.post_types.#{the_slug}", default: the_slug)
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.cama_url_to_fixed("cama_post_type_#{self.id}_#{as_path.present? ? "path" : "url"}", args)
  end

  # return the public url with group structure
  # Sample: http://localhost/group/10-my-group.html
  def the_group_url(*args)
    args = args.extract_options!
    args[:post_type_id] = the_id
    args[:title] = the_title.parameterize
    args[:title] = the_slug unless args[:title].present?
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.cama_url_to_fixed("cama_post_type#{_calc_locale(args[:locale])}_#{as_path.present? ? "path" : "url"}", args)
  end

  # return edit url for this post type
  def the_edit_url
    h.edit_cama_admin_settings_post_type_url(object.id)
  end

  # return the admin list url for this post type
  def the_admin_url(list_type = "post")
    if list_type == "post"
      h.cama_admin_post_type_posts_path(object.id)
    elsif list_type == "tag"
      h.cama_admin_post_type_post_tags_path(object.id)
    else # categories
      h.cama_admin_post_type_categories_path(object.id)
    end
  end

  # add_post_type: true/false to include post type link
  # is_parent: true/false (internal control)
  def generate_breadcrumb(add_post_type = true, is_parent = false)
    h.breadcrumb_add(self.the_title, is_parent ? self.the_url : nil) if add_post_type
  end

  # return main categories (first level) for the post_type (active_record) filtered by permissions
  # in return object, you can add custom where's or pagination like here:
  # http://edgeguides.rubyonrails.org/active_record_querying.html
  def the_categories
    object.categories
  end

  # return full categories (all levels) for the post_type (active_record) filtered by permissions
  # in return object, you can add custom where's or pagination like here:
  # http://edgeguides.rubyonrails.org/active_record_querying.html
  def the_full_categories
    object.full_categories
  end

  # return a category from this post_type with id (integer) or by slug (string)
  def the_category(slug_or_id)
    return the_categories.where(id: slug_or_id).first if slug_or_id.is_a?(Integer)
    return the_categories.find_by_slug(slug_or_id) if slug_or_id.is_a?(String)
  end

  # return all post_tags for the post_type (active_record) filtered by permissions + hidden posts + roles + etc...
  # in return object, you can add custom where's or pagination like here:
  # http://edgeguides.rubyonrails.org/active_record_querying.html
  def the_post_tags
    object.post_tags
  end

  # return thumbnail for this post type
  # default: if thumbnail is not present, will render default
  def the_thumb_url(default = nil)
    th = object.get_option("thumb", object.get_option("default_thumb"))
    th.present? ? th : (default || h.asset_url("camaleon_cms/image-not-found.png"))
  end
end
