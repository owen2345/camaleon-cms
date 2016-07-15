=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::CategoriesTagsForPosts extend ActiveSupport::Concern
  included do
    # data_tags: (String) tags name separated by commas, sample: "Tag1,Tag two,tag new"
    # data_categories: (Array) array of category ids assigned for this post, sample: [1,2,3]
    # attr_accessible :data_tags, :data_categories
    attr_accessor :data_tags, :data_categories

    after_save :save_extra_data
    after_save :check_default_category
  end

  # check if this post can manage categories
  def manage_categories?
    post_type.manage_categories?
  end

  # check if this post can manage tags
  def manage_tags?
    post_type.manage_tags?
  end

  # update category assignations for this post
    # remove assignations that no longer exist
    # add new assignations
  # cats: (Array) array of category ids assigned for this post, sample: [1,2,3]
  def update_categories(cats=[])
    rescue_extra_data
    cats = cats.to_i
    old_categories = categories.pluck("#{CamaleonCms::TermTaxonomy.table_name}.id")
    delete_categories = old_categories - cats
    news_categories =  cats - old_categories
    term_relationships.where("term_taxonomy_id in (?)", delete_categories ).destroy_all   if  delete_categories.present?
    news_categories.each do |key|
      term_relationships.create(:term_taxonomy_id => key)
    end
    update_counters("categories")
  end

  # update tags assignations for this post
    # remove assignations that no longer exist
    # add new assignations
  # tags: (String) tags name separated by commas, sample: "Tag1,Tag two,tag new"
  def update_tags(tags)
    rescue_extra_data
    tags = tags.split(",").strip
    post_tags = self.post_type.post_tags
    post_tags = post_tags.where("name not in (?)", tags) if tags.present?
    self.term_relationships.where("term_taxonomy_id in (?)", post_tags.pluck("#{CamaleonCms::TermTaxonomy.table_name}.id")).destroy_all
    tags.each do |f|
      post_tag = self.post_type.post_tags.where({name: f}).first_or_create(slug: f.parameterize)
      self.term_relationships.where({term_taxonomy_id: post_tag.id}).first_or_create
    end
    update_counters("tags")
  end

  # Assign this post for category with id: category_id
  # categories_id: (Array) array of category ids assigned for this post, sample: [1,2,3]
  def assign_category(categories_id)
    categories_id = [categories_id] if categories_id.is_a?(Integer)
    rescue_extra_data
    categories_id.each do |key|
      term_relationships.where(:term_taxonomy_id => key).first_or_create!
    end
    update_counters("categories")
  end

  # Assign this post for category with id: category_id
  # categories_id: (Array) array of category ids assigned for this post, sample: [1,2,3]
  def unassign_category(categories_id)
    categories_id = [categories_id] if categories_id.is_a?(Integer)
    rescue_extra_data
    term_relationships.where(:term_taxonomy_id => categories_id).destroy_all
    update_counters("categories")
  end

  # Assign new tags to this post
  # tags_title: (String) tags name separated by commas, sample: "Tag1,Tag two,tag new"
  def assign_tags(tag_titles)
    update_counters_before
    tags = tag_titles.split(",").strip
    tags.each do |t|
      post_tag = self.post_type.post_tags.where(name: t).first_or_create!
      self.term_relationships.where({term_taxonomy_id: post_tag.id}).first_or_create!
    end
    update_counters("tags")
  end

  # Unassign tags from this post
  # tags_title: (String) tags name separated by commas, sample: "Tag1,Tag two,tag new"
  def unassign_tags(tag_titles)
    update_counters_before
    tags = tag_titles.split(",").strip
    self.term_relationships.where({term_taxonomy_id: self.post_type.post_tags.where(name: tags).pluck(:id)}).destroy_all
    update_counters("tags")
  end

  # update quantity of posts assigned for tags and categories assigned to this post
  def update_extra_data
    rescue_extra_data
    update_counters
  end

  private
  @cats_before, @tags_before = [], []
  # save as a cache previous categories and tags assigned for this post
  def rescue_extra_data
    @cats_before = self.categories.pluck(:id) if manage_categories?
    @tags_before = self.post_tags.pluck(:id) if manage_tags?
  end

  # update quantity of posts assigned for tags and categories assigned to this post
  # if kind is empty, then this will update both: cats and tags
  # kind: (string) tags | categories
  def update_counters(kind = "")
    self.post_type.full_categories.where(id: (@cats_before + self.categories.pluck(:id)).uniq).each { |c| c.update_column("count", c.posts.published.size) } if ["", "categories"].include?(kind) && manage_categories?
    self.post_type.post_tags.where(id: (@tags_before + self.post_tags.pluck(:id)).uniq).each { |tag| tag.update_column("count", tag.posts.published.size) } if ["", "tags"].include?(kind) && manage_tags?
  end

  # save extra data such as: categories and tags assigned to this post
  def save_extra_data
    update_categories(self.data_categories) if manage_categories? && !self.data_categories.nil?
    update_tags(self.data_tags) if manage_tags? && !self.data_tags.nil?
  end

  # auto assign default categories if none categories were assigned
  def check_default_category
    if manage_categories?
      assign_category([self.post_type.default_category.id]) unless self.categories.present?
    end
  end

end
