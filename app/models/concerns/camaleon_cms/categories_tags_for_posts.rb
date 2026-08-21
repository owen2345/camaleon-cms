module CamaleonCms
  module CategoriesTagsForPosts
    extend ActiveSupport::Concern
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
    # cats: (Array) array of category ids assigned for this post, sample: [1, 2, 3]
    def update_categories(cats = [])
      # a loaded (stale) categories association would keep exposing removed ids to
      # get_field_groups -- the edit form eager-loads categories (the_post includes)
      # before this destroys a relationship
      categories.reset
      rescue_extra_data
      cats = cats.to_i
      old_categories = categories.pluck("#{CamaleonCms::TermTaxonomy.table_name}.id")
      delete_categories = old_categories - cats
      news_categories = cats - old_categories
      term_relationships.where('term_taxonomy_id in (?)', delete_categories).destroy_all if delete_categories.present?
      news_categories.each do |key|
        term_relationships.create(term_taxonomy_id: key)
      end
      update_counts('categories')
    end

    # update tags assignations for this post
    # remove assignations that no longer exist
    # add new assignations
    # tags: (String) tags name separated by commas, sample: "Tag1,Tag two,tag new"
    def update_tags(tags)
      rescue_extra_data
      tags = tags.split(',').strip
      post_tags = post_type.post_tags
      post_tags = post_tags.where.not(name: tags) if tags.present?
      term_relationships.where('term_taxonomy_id in (?)',
                               post_tags.pluck("#{CamaleonCms::TermTaxonomy.table_name}.id")).destroy_all
      tags.each do |f|
        post_tag = post_type.post_tags.where({ name: f }).first_or_create(slug: f.parameterize)
        term_relationships.where({ term_taxonomy_id: post_tag.id }).first_or_create
      end
      update_counts('tags')
    end

    # Assign this post for category with id: category_id
    # categories_id: (Array) array of category ids assigned for this post, sample: [1,2,3]
    def assign_category(categories_id)
      categories_id = [categories_id] if categories_id.is_a?(Integer)
      rescue_extra_data
      categories_id.each do |key|
        term_relationships.where(term_taxonomy_id: key).first_or_create!
      end
      update_counts('categories')
    end

    # Unassign this post from categories with ids: categories_id
    # categories_id: (Array) array of category ids to unassign from this post, sample: [1,2,3]
    def unassign_category(categories_id)
      categories_id = [categories_id] if categories_id.is_a?(Integer)
      # a loaded (stale) categories association would hide the removed ids from the
      # counter refresh below — check_default_category loads it on every save
      categories.reset
      rescue_extra_data
      term_relationships.where(term_taxonomy_id: categories_id).destroy_all
      update_counts('categories')
    end

    # Update the quantity of posts assigned for tags and categories assigned to this post
    def update_extra_data
      rescue_extra_data
      update_counts
    end

    private

    @cats_before = []
    @tags_before = []
    # save as a cache previous categories and tags assigned for this post
    def rescue_extra_data
      @cats_before = categories.pluck(:id) if manage_categories?
      @tags_before = post_tags.pluck(:id) if manage_tags?
    end

    # Update the quantity of posts assigned for tags and categories assigned to this post
    # if kind is empty, then this will update both: cats and tags
    # kind: (string) tags | categories
    def update_counts(kind = '')
      if ['', 'categories'].include?(kind) && manage_categories?
        post_type.full_categories.where(id: (@cats_before + categories.pluck(:id)).uniq).find_each do |c|
          c.update_column(:count, c.posts.published.size) # rubocop:disable Rails/SkipsModelValidations
        end
      end
      return unless ['', 'tags'].include?(kind) && manage_tags?

      post_type.post_tags.where(id: (@tags_before + post_tags.pluck(:id)).uniq).find_each do |tag|
        tag.update_column(:count, tag.posts.published.size) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    # Save extra data such as categories and tags assigned to this post
    def save_extra_data
      update_categories(data_categories) if manage_categories? && !data_categories.nil?
      update_tags(data_tags) if manage_tags? && !data_tags.nil?
    end

    # auto assign default categories if none categories were assigned
    def check_default_category
      return unless manage_categories?

      assign_category([post_type.default_category.id]) if categories.blank?
    end
  end
end
