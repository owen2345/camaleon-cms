=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::UniqValidator < ActiveModel::Validator
  def validate(record)
    unless record.skip_slug_validation?
      record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}" if CamaleonCms::TermTaxonomy.where(slug: record.slug).where.not(id: record.id).where("#{CamaleonCms::TermTaxonomy.table_name}.taxonomy" => record.taxonomy).where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id" => record.parent_id).size > 0
    end
  end
end
class CamaleonCms::TermTaxonomy < ActiveRecord::Base
  include CamaleonCms::Metas
  include CamaleonCms::CustomFieldsRead
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}term_taxonomy"
  # attr_accessible :taxonomy, :description, :parent_id, :count, :name, :slug, :term_group, :status, :term_order, :user_id
  # attr_accessible :data_options
  # attr_accessible :data_metas

  # callbacks
  before_validation :before_validating
  before_destroy :destroy_dependencies

  # validates
  validates :name, :taxonomy, presence: true
  validates_with CamaleonCms::UniqValidator

  # relations
  has_many :term_relationships, :class_name => "CamaleonCms::TermRelationship", :foreign_key => :term_taxonomy_id, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
  belongs_to :parent, class_name: "CamaleonCms::TermTaxonomy", foreign_key: :parent_id
  belongs_to :owner, class_name: "CamaleonCms::User", foreign_key: :user_id

  # return all children taxonomy
  # sample: sub categories of a category
  def children
    CamaleonCms::TermTaxonomy.where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id = ?", self.id)
  end

  # return all menu items in which this taxonomy was assigned
  def in_nav_menu_items
    CamaleonCms::NavMenuItem.where(url: self.id, kind: self.taxonomy)
  end

  # permit to skip slug validations for children models, like menu items
  def skip_slug_validation?
    false
  end

  private
  # callback before validating
  def before_validating
    slug = self.slug
    slug = self.name if slug.blank?
    self.name = slug unless self.name.present?
    self.slug = slug.to_s.parameterize.try(:downcase)
  end

  # destroy all dependencies
  # unassign all items from menus
  def destroy_dependencies
    in_nav_menu_items.destroy_all
  end

end
