=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CategoryDecorator < TermTaxonomyDecorator
  delegate_all

  # return the public url for this category
  def the_url(*args)
    args = args.extract_options!
    args[:category_id] = the_id
    args[:title] = the_title.parameterize
    args[:locale] = @_deco_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.url_to_fixed("category#{_calc_locale(args[:locale])}_#{as_path.present? ? "path" : "url"}", args)
  end

  # return all children categories for the current category (active_record) filtered by permissions + hidden posts + roles + etc...
  # in return object, you can add custom where's or pagination like here:
  # http://edgeguides.rubyonrails.org/active_record_querying.html
  def the_categories
    object.categories
  end

  # return a child category from this category with id (integer) or by slug (string)
  def the_category(slug_or_id)
    return object.categories.where(id: slug_or_id).first if slug_or_id.is_a?(Integer)
    return object.categories.find_by_slug(slug_or_id) if slug_or_id.is_a?(String)
  end

  # ---------------------
  # add_post_type: true/false to include post type link
  # is_parent: true/false (internal control)
  def generate_breadcrumb(add_post_type = true, is_parent = false)
    _parent = object.parent
    if _parent.present?
      _parent.decorate.generate_breadcrumb(add_post_type, true)
    else
      object.post_type_parent.decorate.generate_breadcrumb(add_post_type, true)
    end
    h.breadcrumb_add(self.the_title, is_parent ? self.the_url : nil)
  end

  # return thumbnail for this post type
  # default: if thumbnail is not present, will render default
  def the_thumb_url(default = nil)
    th = object.get_option("thumb")
    th.present? ? th : (default || h.asset_path("category-icon.png"))
  end

  # return the post type of this post tag
  def the_post_type
    object.post_type.decorate
  end
end
