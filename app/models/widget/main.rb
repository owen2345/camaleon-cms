=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Widget::Main < TermTaxonomy
  default_scope { where(taxonomy: :widget) }
  attr_accessible :excerpt, :renderer
  # name: "title"
  # description: "content for this"
  # slug: "key for this"
  # status = simple or complex (default)
  # excerpt: string for message
  # renderer: string (path to the template for render this widget)

  has_many :metas, ->{ where(object_class: 'Widget::Main')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :owner, class_name: "User", foreign_key: :user_id
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id

  has_many :assigned, class_name: "Widget::Assigned", foreign_key: :visibility, dependent: :destroy
  before_save :check_excerpt
  def is_simple?
    self.status == "simple"
  end

  def excerpt=(value)
    @excerpt = value
  end
  def excerpt
    self.get_option("excerpt")
  end

  def renderer=(value)
    @renderer = value
  end
  def renderer
    self.get_option("renderer")
  end

  private
  def check_excerpt
    self.set_option("excerpt", @excerpt)
    self.set_option("renderer", @renderer)
  end
end
