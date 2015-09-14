=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class PostTagDecorator < TermTaxonomyDecorator
  delegate_all

  # return the public url for this post tag
  def the_url(*args)
    args = args.extract_options!
    args[:post_tag_id] = the_id
    args[:title] = the_title
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.url_to_fixed("post_tag#{_calc_locale(args[:locale])}_#{as_path.present? ? "path" : "url"}", args)
  end

  # return the post type of this post tag
  def the_post_type
    object.post_type.decorate
  end

  # ---------------------
  # add_post_type: true/false to include post type link
  # is_parent: true/false (internal control)
  def generate_breadcrumb(add_post_type = true, is_parent = false)
    object.post_type.decorate.generate_breadcrumb(add_post_type, true)
    h.breadcrumb_add(self.the_title)
  end
end
