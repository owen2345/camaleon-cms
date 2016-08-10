=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::CustomFieldsRelationship < ActiveRecord::Base
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}custom_fields_relationships"
  # attr_accessible :objectid, :custom_field_id, :term_order, :value, :object_class, :custom_field_slug, :group_number
  default_scope {order("#{CamaleonCms::CustomFieldsRelationship.table_name}.term_order ASC")}
  # relations
  belongs_to :custom_fields, :class_name => "CamaleonCms::CustomField", foreign_key: :custom_field_id

  # validates :objectid, :custom_field_id, presence: true
  validates :custom_field_id, presence: true # error on clone model

  after_save :set_parent_slug

  private
  def set_parent_slug
    #self.update_column('custom_field_slug', self.custom_fields.slug)
  end

end
