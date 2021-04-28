module CamaleonCms
  class PostTag < CamaleonCms::TermTaxonomy
    default_scope { where(taxonomy: :post_tag) }

    cama_define_common_relationships('PostTag')
    has_many :posts, foreign_key: :objectid, through: :term_relationships, source: :object
    belongs_to :post_type, foreign_key: :parent_id, inverse_of: :post_tags
    belongs_to :owner, class_name: CamaManager.get_user_class_name, foreign_key: :user_id
  end
end
