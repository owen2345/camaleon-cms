=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::NavMenuItem < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :nav_menu_item).order(id: :asc) }
  has_many :metas, ->{ where(object_class: 'NavMenuItem')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :parent, class_name: "CamaleonCms::NavMenu"
  belongs_to :parent_item, class_name: "CamaleonCms::NavMenuItem", foreign_key: :parent_id
  has_many :children, class_name: "CamaleonCms::NavMenuItem", foreign_key: :parent_id, dependent: :destroy

  after_create :update_count
  #before_destroy :update_count
  alias_attribute :site_id, :term_group
  alias_attribute :label, :name

  # return the main menu
  def main_menu
    main_menu = self.parent
    return main_menu if main_menu.present?
    parent_menu = self.parent_item
    parent_menu.main_menu if parent_menu.present?
  end

  # return the type of this menu (post|category|post_tag|post_type|external)
  def get_type
    self.get_option('type')
  end

  # return the url of the external menu item
  # return the object_id of menus like posttype, post, category, ...
  def url
    get_option('object_id')
  end

  # check if this menu have children
  def have_children?
    self.children.count != 0
  end

  # add sub menu for a menu item
  # same values of NavMenu#append_menu_item
  # return item created
  def append_menu_item(value)
    children.create({name: value[:label], data_options: {type: value[:type], object_id: value[:link]}})
  end

  # update current menu
  # value: same as append_menu_item (label, link)
  def update_menu_item(value)
    self.update({name: value[:label], data_options: {object_id: value[:link]}})
  end

  # skip uniq slug validation
  def skip_slug_validation?
    true
  end

  private
  def update_count
    self.parent.update_column('count', self.parent.children.size) if self.parent.present?
    self.parent_item.update_column('count', self.parent_item.children.size) if self.parent_item.present?
    self.update_column(:term_group, main_menu.parent_id)
  end
end
