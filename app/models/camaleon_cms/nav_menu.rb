=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::NavMenu < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :nav_menu).order(id: :asc) }
  has_many :metas, ->{ where(object_class: 'NavMenu')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  has_many :children, class_name: "CamaleonCms::NavMenuItem", foreign_key: :parent_id, dependent: :destroy
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id

  # add menu item for current menu
  # value: (Hash) is a hash object that contains label, type, link
  #   options for type: post | category | post_type | post_tag | external
  # sample: {label: "my label", type: "external", link: "http://camaleon.tuzitio.com"}
  # sample: {label: "my label", type: "post", link: 10}
  # sample: {label: "my label", type: "category", link: 12}
  # return item created
  def append_menu_item (value)
    item = children.create!({name: value[:label], data_options: {type: value[:type], object_id: value[:link]}})
    item
  end

  # skip uniq slug validation
  def skip_slug_validation?
    true
  end

  private
  # overwrite termtaxonomy method
  def destroy_dependencies
  end
end
