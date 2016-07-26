=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::CustomField < ActiveRecord::Base
  self.primary_key = :id
  include CamaleonCms::Metas
  has_many :metas, ->{ where(object_class: 'CustomField')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}custom_fields"
  default_scope {order("#{CamaleonCms::CustomField.table_name}.field_order ASC")}
  # status: nil -> visible on list group fields
  # attr_accessible :object_class, :objectid, :description, :parent_id, :count, :name, :slug, :field_order, :status, :is_repeat
  validates :name, :object_class, presence: true
  has_many :values, :class_name => "CamaleonCms::CustomFieldsRelationship", :foreign_key => :custom_field_id, dependent: :destroy
  belongs_to :custom_field_group, class_name: "CamaleonCms::CustomFieldGroup"
  belongs_to :parent, class_name: "CamaleonCms::CustomField", :foreign_key => :parent_id
  alias_attribute :label, :name
  validates_uniqueness_of :slug, scope: [:parent_id, :object_class], unless: lambda{|o| o.is_a?(CamaleonCms::CustomFieldGroup) }

  scope :configuration, -> {where(parent_id: -1)}
  scope :visible_group, -> {where(status: nil)}

  before_validation :before_validating

  private
  def before_validating
    self.slug = self.name if self.slug.blank?
    self.slug = self.slug.to_s.parameterize
  end
end
