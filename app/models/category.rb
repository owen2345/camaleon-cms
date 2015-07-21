class Category < TermTaxonomy
  # term_group = site_id
  # status = post_type_id

  default_scope { where(taxonomy: :category) }
  has_many :metas, ->{ where(object_class: 'Category')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
  has_many :children, class_name: "Category", foreign_key: :parent_id
  belongs_to :parent, class_name: "Category", foreign_key: :parent_id
  belongs_to :post_type_parent, class_name: "PostType", foreign_key: :parent_id
  belongs_to :owner, class_name: "User", foreign_key: :user_id

  scope :no_empty, ->{ where("count > 0") }

  #scope :parents, -> { where("term_taxonomy.parent_id IS NULL") }

  before_save :set_site
  before_destroy :set_posts_in_default_category

  # return the post type of this category
  def post_type
    ctg = self
    begin
      pt = ctg.post_type_parent
      ctg = ctg.parent
    end while ctg.present?
    pt
  end

  private
  def set_site
    pt = self.post_type
    self.term_group = pt.site.id unless self.term_group.present?
    self.status = pt.id unless self.status.present?
  end

  def set_posts_in_default_category
    category_default = self.post_type.default_category
    return if category_default == self
    self.posts.each do |post|
      if post.categories.where.not(id: self.id).blank?
        post.assign_category(category_default.id)
      end
    end
  end

end
