module CamaleonCms
  class PostTag < CamaleonCms::TermTaxonomy
    has_many :posts, foreign_key: :objectid, through: :term_relationships, source: :object
    belongs_to :post_type, foreign_key: :parent_id, inverse_of: :post_tags, required: false
    belongs_to :owner, class_name: CamaManager.get_user_class_name, foreign_key: :user_id, required: false

    has_many :field_values, as: :record, dependent: :destroy
    delegate :field_groups, :fields, to: :post_type, prefix: :postag
  end
end
