=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class PostUniqValidator < ActiveModel::Validator
  def validate(record)
    if record.status != 'draft'
      slug_array = record.slug.to_s.translations_array
      ptype = record.post_type
      if ptype.present? # only for posts that belongs to a post type model
        posts = ptype.site.posts.where("(#{slug_array.map {|s| "posts.slug LIKE '%-->#{s}<!--%'"}.join(" OR ")} ) OR posts.slug = ?",  record.slug).where("posts.status != 'draft'").where(post_parent: nil).where.not(id: record.id)
        if posts.size > 0
          if slug_array.size > 1
            record.errors[:base] << "#{I18n.t('admin.post.message.requires_different_slug')}: #{posts.pluck(:slug).map{|slug| record.slug.to_s.translations.map{|lng, r_slug| "#{r_slug} (#{lng})" if slug.translations_array.include?(r_slug) }.join(",") }.join(",").split(",").uniq.clean_empty.join(", ")} "
          else
            record.errors[:base] << "#{I18n.t('admin.post.message.requires_different_slug')}: #{record.slug.to_s} "
          end
        end
      else
        # validation for other classes
      end
    end
  end
end

class Post < PostDefault
  include CategoriesTagsForPosts
  default_scope ->{ where(post_class: self.name) }
  has_many :metas, ->{ where(object_class: 'Post')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :post_relationships, class_name: "PostRelationship", foreign_key: :objectid, dependent: :destroy,  inverse_of: :posts
  has_many :post_types, class_name: "PostType", through: :post_relationships, :source => :post_type
  has_many :term_relationships, class_name: "TermRelationship", foreign_key: :objectid, dependent: :destroy,  inverse_of: :objects
  has_many :categories, class_name: "Category", through: :term_relationships, :source => :term_taxonomies
  has_many :post_tags, class_name: "PostTag", through: :term_relationships, :source => :term_taxonomies
  has_many :comments, class_name: "PostComment", foreign_key: :post_id, dependent: :destroy
  has_many :drafts, ->{where(status: 'draft')}, class_name: "Post", foreign_key: :post_parent, dependent: :destroy
  has_many :children, class_name: "Post", foreign_key: :post_parent, dependent: :destroy, primary_key: :id

  belongs_to :owner, class_name: "User", foreign_key: :user_id
  belongs_to :parent, class_name: "Post", foreign_key: :post_parent

  scope :visible_frontend, -> {where(status: 'published')}
  scope :public_posts, -> {visible_frontend.where(visibility: ['public', ""]) } #public posts (not passwords, not privates)

  scope :trash, -> {where(status: 'trash')}
  scope :no_trash, -> {where.not(status: 'trash')}
  scope :published, -> {where(status: 'published')}
  scope :drafts, -> {where(status: 'draft')}
  scope :pendings, -> {where(status: 'pending')}
  scope :latest, -> {reorder(created_at: :desc)}

  validates_with PostUniqValidator

  def post_type=(pt)
    @_cache_post_type = pt
  end
  def post_type
    @_cache_post_type ||= (post_types.reorder(nil).first || post_relationships.first.post_type)
  end

  # return template assigned to this post
  def template
    get_meta("template", "")
  end

  # return default template assigned to this post
  def default_template
    get_option("default_template")
  end

  # check if this post was published
  def published?
    status == 'published'
  end

  # check if this is in pending status
  def pending?
    status == 'pending'
  end

  # check if this is in draft status
  def draft?
    status == 'draft'
  end

  # check if this is in trash status
  def trash?
    status == 'trash'
  end

  # check if current post can manage content
  # return boolean
  def manage_content?(posttype = nil)
    get_option('has_content', false) || (posttype || self.post_type).get_option('has_content', true)
  end

  # check if current post can manage summary
  # return boolean
  def manage_summary?(posttype = nil)
    get_option('has_summary', false) || (posttype || self.post_type).get_option('has_summary', true)
  end

  # check if current post can manage keywords
  # return boolean
  def manage_keywords?(posttype = nil)
    get_option('has_keywords', false) || (posttype || self.post_type).get_option('has_keywords', true)
  end

  # check if current post can manage picture
  # return boolean
  def manage_picture?(posttype = nil)
    get_option('has_picture', false) || (posttype || self.post_type).get_option('has_picture', true)
  end

  # check if current post can manage template
  # return boolean
  def manage_template?(posttype = nil)
    get_option('has_template', false) || (posttype || self.post_type).get_option('has_template', true)
  end

  # check if current post can manage comments
  # return boolean
  def manage_comments?(posttype = nil)
    get_option('has_comments', false) || (posttype || self.post_type).get_option('has_comments', false)
  end

  # define post configuration for current post
  # possible key values (String):
  #   has_content, boolean
  #   has_summary, boolean
  #   has_keywords, boolean
  #   has_picture, boolean
  #   has_template, boolean
  #   has_comments, boolean
  #   default_template: template name rendered by default, the value accept a String
  # val: value for the setting
  def set_setting(key, val)
    set_option(key, val)
  end

  # assign multiple settings
  def set_settings(settings = {})
    settings.each do |key, val|
      set_option(key, val)
    end
  end
end
