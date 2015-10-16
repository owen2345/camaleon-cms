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
    record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}" if CamaleonCms::TermTaxonomy.where(slug: record.slug).where.not(id: record.id).where("#{CamaleonCms::TermTaxonomy.table_name}.taxonomy" => record.taxonomy).where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id" => record.parent_id).size > 0
  end
end
class CamaleonCms::TermTaxonomy < ActiveRecord::Base
  include CamaleonCms::Metas
  include CamaleonCms::CustomFieldsRead
  self.table_name = "#{PluginRoutes.system_info["db_prefix"]}term_taxonomy"
  attr_accessible :taxonomy, :description, :parent_id, :count, :name, :slug, :term_group, :status, :term_order, :user_id

  # callbacks

  after_create :set_default_options
  before_validation :before_validating
  before_destroy :destroy_dependencies
  # validates
  validates :name, :taxonomy, presence: true
  validates_with CamaleonCms::UniqValidator

  #default_scope order('users.role ASC')
  # relations
  has_many :term_relationships, :class_name => "CamaleonCms::TermRelationship", :foreign_key => :term_taxonomy_id, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
  belongs_to :parent, class_name: "CamaleonCms::TermTaxonomy", foreign_key: :parent_id
  has_many :user_relationships, :class_name => "CamaleonCms::UserRelationship", :foreign_key => :term_taxonomy_id, dependent: :destroy
  has_many :users, through: :user_relationships, :source => :user

  # default taxonomies
  def self.wp_taxonomies
    data = {}
    data[:category] = {
        options: {
        },
        options_editable:{

        }
    }
    data[:post_tag] = {
        options: {
        },
        options_editable:{

        }
    }
    data[:nav_menu] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:nav_menu_item] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:post_type] = {
        options: {
            has_category: false,
            has_tags: false,
            has_summary: true,
            has_content: true,
            has_comments: false,
            has_picture: true,
            has_template: true,
            not_deleted: false
        },
        options_editable:{
            has_category:{type: 'checkbox', label: 'Has Category'},
            has_tags:{type: 'checkbox', label: 'Has Tags'}
        }
    }
    data[:site] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:widget] = {
        options: {
        },
        options_editable:{
        }
    }
    data[:form] = {
        options: {
        },
        options_editable:{
        }
    }
    data.to_sym
  end

  def self.find_by_slug(slug)
    self.where("#{CamaleonCms::TermTaxonomy.table_name}.slug = ? OR #{CamaleonCms::TermTaxonomy.table_name}.slug LIKE ? ", slug, "%-->#{slug}<!--%").reorder("").first
  end

  def term_children(taxy='')
    CamaleonCms::TermTaxonomy.where(taxonomy: taxy).where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id = ?", self.id)
  end

  def children
    CamaleonCms::TermTaxonomy.where("#{CamaleonCms::TermTaxonomy.table_name}.parent_id = ?", self.id)
  end


  def set_options_from_form(metas = [])
    if metas.present?
      metas.each do |key, value|
        self.set_option(key, value)
      end
    end
  end

  # return all menu items in which this taxonomy was assigned
  def in_nav_menu_items
    CamaleonCms::NavMenuItem.joins(:metas).where("value LIKE ?","%\"object_id\":\"#{self.id}\"%").where("value LIKE ?","%\"type\":\"#{self.taxonomy}\"%").readonly(false)
  end

  private

  def set_default_options
    begin
      values = CamaleonCms::TermTaxonomy::wp_taxonomies[taxonomy.to_sym][:options]
      self.set_meta('_default', values) if self.id.present? && values.present?
      values
    rescue
      # TODO what happend here (values = TermTaxonomy::wp_taxonomies[taxonomy.to_sym][:options]) undefined method `[]' for nil:NilClass
    end
  end

  def before_validating
    slug = self.slug
    slug = self.name if slug.blank?
    self.name = slug unless self.name.present?
    if slug.to_s.translations.present?
      self.slug = slug.to_s.translations.inject({}) { |h, (k, v)| h[k] = v.to_s.parameterize; h }.to_translate
    else
      self.slug = slug.to_s.parameterize
    end
  end

  def destroy_dependencies
    in_nav_menu_items.destroy_all
  end


end
