class CamaleonCms::Category < CamaleonCms::TermTaxonomy
  alias_attribute :site_id, :term_group
  alias_attribute :post_type_id, :status

  default_scope { where(taxonomy: :category) }
  scope :no_empty, -> { where('count > 0') } # return all categories that contains at least one post
  scope :empty, -> { where(count: [0, nil]) } # return all categories that does not contain any post
  # scope :parents, -> { where("term_taxonomy.parent_id IS NULL") }

  has_many :metas, -> { where(object_class: 'Category') }, class_name: 'CamaleonCms::Meta',
    foreign_key: :objectid, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, source: :objects
  has_many :children, class_name: 'CamaleonCms::Category', foreign_key: :parent_id,
    dependent: :destroy
  belongs_to :parent, class_name: 'CamaleonCms::Category', foreign_key: :parent_id
  belongs_to :post_type_parent, class_name: 'CamaleonCms::PostType', foreign_key: :parent_id,
    inverse_of: :categories
  belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :site_id

  before_save :set_site
  before_destroy :set_posts_in_default_category

  # return the post type of this category
  def post_type
    cama_fetch_cache('post_type') do
      ctg = self
      begin
        pt = ctg.post_type_parent
        ctg = ctg.parent
      end while ctg.present?
      pt
    end
  end

  private

  def set_site
    pt = self.post_type
    self.site_id = pt.site_id unless site_id.present?
    self.status = pt.id unless status.present?
  end

  # rescue all posts to assign into default category if they don't have any category assigned
  def set_posts_in_default_category
    category_default = self.post_type.default_category
    return if category_default == self
    self.posts.each do |post|
      if post.categories.where.not(id: id).blank?
        post.assign_category(category_default.id)
      end
    end
  end
end
