module CamaleonCms
  class PostTag < CamaleonCms::TermTaxonomy
    normalize_attrs(:description)

    has_many :posts, foreign_key: :objectid, through: :term_relationships, source: :object
    belongs_to :post_type, foreign_key: :parent_id, inverse_of: :post_tags, optional: true
    belongs_to :owner, class_name: CamaManager.get_user_class_name.to_s, foreign_key: :user_id, optional: true,
                       inverse_of: :post_tags
  end
end
