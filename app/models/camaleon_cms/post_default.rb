=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::PostDefault < ActiveRecord::Base
  include CamaleonCms::Metas
  include CamaleonCms::CustomFieldsRead
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}posts"

  # attr_accessible :user_id, :title, :slug, :content, :content_filtered, :status,  :visibility, :visibility_value, :post_order, :post_type_key, :taxonomy_id, :published_at, :post_parent, :post_order, :is_feature
  attr_accessor :draft_id
  # attr_accessible :data_options
  # attr_accessible :data_metas
  cattr_accessor :current_user
  cattr_accessor :current_site

  has_many :term_relationships, class_name: "CamaleonCms::TermRelationship", foreign_key: :objectid, dependent: :destroy, primary_key: :id
  has_many :children, ->{ where(post_class: "PostDefault") }, class_name: "CamaleonCms::PostDefault", foreign_key: :post_parent, dependent: :destroy, primary_key: :id
  scope :featured, ->{ where(is_feature: true) }

  validates :title, :slug, presence: true

  # callbacks
  before_validation :before_validating
  before_save :before_saved
  before_destroy :destroy_dependencies


  # find a content by slug (support multi language)
  def self.find_by_slug(slug)
    if current_site.present? && current_site.get_meta("languages_site", []).count <= 1
      res = self.where(slug: slug)
    else
      res = self.where("#{CamaleonCms::Post.table_name}.slug = ? OR #{CamaleonCms::Post.table_name}.slug LIKE ? ", slug, "%-->#{slug}<!--%")
    end
    res.reorder("").first
  end

  # return the parent of a post (support for sub contents or tree of posts)
  def parent
    CamaleonCms::Post.where(id: self.post_parent).first
  end

  # return the author of this Content
  def author
    begin
      CamaleonCms::User.find(self.user_id)
    rescue
      CamaleonCms::User.admin_scope.first
    end
  end

  # return all menu items in which this post was assigned
  def in_nav_menu_items
    CamaleonCms::NavMenuItem.where(url: self.id, kind: 'post')
  end

  # Set the meta, field values and the post keywords here
  def set_params(meta, custom_fields, options)
    self.set_metas(meta)
    self.set_field_values(custom_fields)
    self.set_options(options)
  end

  private
  def before_validating
    #self.slug = self.title if self.slug.blank?
    #self.slug = self.slug.to_s.parameterize
  end

  # do all before actions to save the content
  def before_saved
    self.title = "Untitled" unless self.title.present?
    self.content_filtered = content.to_s.include?('<!--:-->') ? content.translations.inject({}) { |h, (key, value)| h[key] = value.squish.strip_tags; h }.to_translate : content.to_s.squish.strip_tags
  end

  # destroy all dependencies of this content
  # unassign this items from menus
  def destroy_dependencies
    in_nav_menu_items.destroy_all
  end
end
