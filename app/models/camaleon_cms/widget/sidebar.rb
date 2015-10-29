=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Widget::Sidebar < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :sidebar) }
  has_many :metas, ->{ where(object_class: 'Widget::Sidebar')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  has_many :assigned, foreign_key: :post_parent, dependent: :destroy
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id

  #scopes
  scope :default_sidebar, -> { where(:slug => 'default-sidebar') }
  scope :all_sidebar, -> { where("slug != 'default-sidebar'") }

  # assign the widget into this sidebar
  # widget: string(slug)/object
  # data: {title, content}
  def add_widget(widget, data = {})
    widget = self.site.widgets.where(slug: widget).first if widget.is_a?(String)
    data[:widget_id] = widget.id
    self.assigned.create(data)
  end

end
