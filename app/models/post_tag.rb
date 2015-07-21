class PostTag < TermTaxonomy
  default_scope { where(taxonomy: :post_tag) }
  has_many :metas, ->{ where(object_class: 'PostTag')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
  belongs_to :post_type, class_name: "PostType", foreign_key: :parent_id
  belongs_to :owner, class_name: "User", foreign_key: :user_id
end
