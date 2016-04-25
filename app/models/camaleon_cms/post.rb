=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::PostUniqValidator < ActiveModel::Validator
  def validate(record)
    if record.status != 'draft'
      slug_array = record.slug.to_s.translations_array
      ptype = record.post_type
      if ptype.present? # only for posts that belongs to a post type model
        posts = ptype.site.posts.where("(#{slug_array.map {|s| "#{CamaleonCms::Post.table_name}.slug LIKE '%-->#{s}<!--%'"}.join(" OR ")} ) OR #{CamaleonCms::Post.table_name}.slug = ?",  record.slug).where("#{CamaleonCms::Post.table_name}.status != 'draft'").where.not(id: record.id)
        if posts.size > 0
          if slug_array.size > 1
            record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{posts.pluck(:slug).map{|slug| record.slug.to_s.translations.map{|lng, r_slug| "#{r_slug} (#{lng})" if slug.translations_array.include?(r_slug) }.join(",") }.join(",").split(",").uniq.clean_empty.join(", ")} "
          else
            record.errors[:base] << "#{I18n.t('camaleon_cms.admin.post.message.requires_different_slug')}: #{record.slug.to_s} "
          end
        end

        # avoid recursive page parent
        record.errors[:base] << I18n.t('camaleon_cms.admin.post.message.recursive_hierarchy', default: 'Parent Post Recursive') if record.post_parent.present? && ptype.manage_hierarchy? && record.parents.cama_pluck(:id).include?(record.id)
      else
        # validation for other classes
      end
    end
  end
end

class CamaleonCms::Post < CamaleonCms::PostDefault
  include CamaleonCms::CategoriesTagsForPosts
  default_scope ->{ where(post_class: "Post").order(post_order: :asc, created_at: :desc) }
  has_many :metas, ->{ where(object_class: 'Post')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :delete_all

  # DEPRECATED
  has_many :post_relationships, class_name: "CamaleonCms::PostRelationship", foreign_key: :objectid, dependent: :destroy,  inverse_of: :posts
  has_many :post_types, class_name: "CamaleonCms::PostType", through: :post_relationships, :source => :post_type
  # END DEPRECATED

  has_many :term_relationships, class_name: "CamaleonCms::TermRelationship", foreign_key: :objectid, dependent: :destroy,  inverse_of: :objects
  has_many :categories, class_name: "CamaleonCms::Category", through: :term_relationships, :source => :term_taxonomies
  has_many :post_tags, class_name: "CamaleonCms::PostTag", through: :term_relationships, :source => :term_taxonomies
  has_many :comments, class_name: "CamaleonCms::PostComment", foreign_key: :post_id, dependent: :destroy
  has_many :drafts, ->{where(status: 'draft')}, class_name: "CamaleonCms::Post", foreign_key: :post_parent, dependent: :destroy
  has_many :children, class_name: "CamaleonCms::Post", foreign_key: :post_parent, dependent: :destroy, primary_key: :id

  belongs_to :owner, class_name: "CamaleonCms::User", foreign_key: :user_id
  belongs_to :parent, class_name: "CamaleonCms::Post", foreign_key: :post_parent
  belongs_to :post_type, class_name: "CamaleonCms::PostType", foreign_key: :taxonomy_id

  scope :visible_frontend, -> {where(status: 'published')}
  scope :public_posts, -> {visible_frontend.where(visibility: ['public', ""]) } #public posts (not passwords, not privates)

  scope :trash, -> {where(status: 'trash')}
  scope :no_trash, -> {where.not(status: 'trash')}
  scope :published, -> {where(status: 'published')}
  scope :root_posts, -> {where(post_parent: [nil, ''])}
  scope :drafts, -> {where(status: 'draft')}
  scope :pendings, -> {where(status: 'pending')}
  scope :latest, -> {reorder(created_at: :desc)}

  validates_with CamaleonCms::PostUniqValidator
  attr_accessor :show_title_with_parent

  # return all parents for current page hierarchy ordered bottom to top
  def parents
    cama_fetch_cache("parents_#{self.id}") do
      res = []
      p = self.parent
      while p.present?
        res << p
        p = p.parent
      end
      res
    end
  end

  # return all children elements for current post (page hierarchy)
  def full_children
    cama_fetch_cache("full_children_#{self.id}") do
      res = self.children.to_a
      res.each{|c|  res += c.full_children }
      res
    end
  end

  # return the post type of this post (DEPRECATED)
  def get_post_type_depre
    post_types.reorder(nil).first
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
    get_option('has_content', (posttype || self.post_type).get_option('has_content', true))
  end

  # return boolean
  def manage_layout?(posttype = nil)
    get_option('has_layout', (posttype || self.post_type).get_option('has_layout', false))
  end

  # check if current post can manage template
  # return boolean
  def manage_template?(posttype = nil)
    get_option('has_template', (posttype || self.post_type).get_option('has_template', true))
  end

  # check if current post can manage summary
  # return boolean
  def manage_summary?(posttype = nil)
    get_option('has_summary', (posttype || self.post_type).get_option('has_summary', true))
  end

  # check if current post can manage keywords
  # return boolean
  def manage_keywords?(posttype = nil)
    get_option('has_keywords', (posttype || self.post_type).get_option('has_keywords', true))
  end

  # check if current post can manage picture
  # return boolean
  def manage_picture?(posttype = nil)
    get_option('has_picture', (posttype || self.post_type).get_option('has_picture', true))
  end

  # check if current post can manage comments
  # return boolean
  def manage_comments?(posttype = nil)
    get_option('has_comments', (posttype || self.post_type).get_option('has_comments', false))
  end

  # check if the post can be commented
  # sample: @post.can_commented?
  # return Boolean (true/false)
  def can_commented?
    manage_comments? && get_meta('has_comments').to_s == "1"
  end

  # define post configuration for current post
  # possible key values (String):
  #   has_content, boolean (default true)
  #   has_summary, boolean (default true)
  #   has_keywords, boolean (default true)
  #   has_picture, boolean (default true)
  #   has_template, boolean (default false)
  #   has_comments, boolean (default false)
  #   default_layout:  (string) (default layout) # this is still used if post type was inactivated layout and overwritten by dropdown in post view
  #   default_template:  (string) (default template) # this is still used if post type was inactivated template and overwritten by dropdown in post view
  #   has_layout:  (boolean) (default false)
  #   skip_fields:  (array) (default empty) array of custom field keys to avoid for this post, sample: ["subtitle", "icon"]
  # val: value for the setting
  def set_setting(key, val)
    set_option(key, val)
  end

  # assign multiple settings
  def set_settings(settings = {})
    settings.each do |key, val|
      set_setting(key, val)
    end
  end

  # put a new order position for this post
  # new_order_position: (Integer) position number
  # return nil
  def set_position(new_order_position)
    self.update_column("post_order", new_order_position)
  end

  # save the summary for current post
  # summary: Text String without html
  def set_summary(summary)
    set_meta("summary", summary)
  end

  # save the thumbnail url for current post
  # thumb_url: String url
  def set_thumb(thumb_url)
    set_meta("thumb", thumb_url)
  end

  # save the layout name to be used on render this post
  # layout_name: String layout name: my_layout.html.erb => 'my_layout'
  def set_layout(layout_name)
    set_meta("layout", layout_name)
  end

  # return the layout assigned to this post
  # post_type: post type owner of this post
  def get_layout(posttype = nil)
    return get_option("default_template") if !manage_layout?(posttype)
    get_meta('layout', get_option("default_layout") || (posttype || self.post_type).get_option('default_layout', nil))
  end

  # return the template assigned to this post
  # verify default template defined in post type
  # post_type: post type owner of this post
  def get_template(posttype = nil)
    return get_option("default_template") if !manage_template?(posttype)
    get_meta('template', get_option("default_template") || (posttype || self.post_type).get_option('default_template', nil))
  end

  # increment the counter of visitors
  def increment_visits!
    set_meta("visits", total_visits+1)
  end

  # return the quantity of visits for this post
  def total_visits
    get_meta("visits", 0).to_i
  end

  # return the quantity of comments for this post
  # TODO comments count
  def total_comments
    self.get_meta("comments_count", 0).to_i
  end
end
