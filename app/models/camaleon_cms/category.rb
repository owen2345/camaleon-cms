module CamaleonCms
  class Category < CamaleonCms::TermTaxonomy
    alias_attribute :site_id, :term_group
    alias_attribute :post_type_id, :status

    default_scope { where(taxonomy: :category) }
    scope :no_empty, -> { where('count > 0') } # return all categories that contains at least one post
    scope :empty, -> { where(count: [0, nil]) } # return all categories that does not contain any post
    # scope :parents, -> { where("term_taxonomy.parent_id IS NULL") }

    has_many :posts, foreign_key: :objectid, through: :term_relationships, source: :object
    has_many :children, class_name: 'CamaleonCms::Category', foreign_key: :parent_id, dependent: :destroy
    belongs_to :parent, class_name: 'CamaleonCms::Category', foreign_key: :parent_id, required: false
    belongs_to :post_type_parent, class_name: 'CamaleonCms::PostType', foreign_key: :parent_id,
                                  inverse_of: :categories, required: false
    belongs_to :site, required: false

    before_save :set_site
    before_destroy :set_posts_in_default_category

    # return the post type of this category
    def post_type
      cama_fetch_cache('post_type') do
        ctg = self
        loop do
          pt = ctg.post_type_parent
          ctg = ctg.parent
          break pt unless ctg
        end
      end
    end

    private

    def set_site
      self.site_id ||= post_type.site_id
      self.status ||= post_type.id
    end

    # rescue all posts to assign into default category if they don't have any category assigned
    def set_posts_in_default_category
      category_default = post_type.default_category
      return if category_default == self

      posts.each do |post|
        post.assign_category(category_default.id) if post.categories.where.not(id: id).blank?
      end
    end
  end
end
