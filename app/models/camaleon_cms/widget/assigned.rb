=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Widget::Assigned < CamaleonCms::PostDefault
  default_scope ->{ where(post_class: self.name).order(:taxonomy_id) }
  # post_parent: sidebar_id
  # visibility: widget_id
  # comment_count: item_order
  # TODO rename all attribute names (changed comment_count into taxonomy_id)
  alias_attribute :widget_id, :visibility
  alias_attribute :sidebar_id, :post_parent
  alias_attribute :item_order, :taxonomy_id

  # attr_accessible :widget_id, :sidebar_id, :item_order

  has_many :metas, ->{ where(object_class: 'Widget::Assigned')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :sidebar, class_name: "CamaleonCms::Widget::Sidebar", foreign_key: :post_parent
  belongs_to :widget, class_name: "CamaleonCms::Widget::Main", foreign_key: :visibility
  after_initialize :fix_slug2
  before_create :set_order

  def fix_slug2
    self.slug = "slug_assigned" unless self.slug.present?
  end

  private
  def set_order
    self.item_order = self.sidebar.assigned.count + 1
  end
end
