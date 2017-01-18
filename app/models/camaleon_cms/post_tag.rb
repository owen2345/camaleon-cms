class CamaleonCms::PostTag < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :post_tag) }
  has_many :metas, ->{ where(object_class: 'PostTag')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  has_many :posts, foreign_key: :objectid, through: :term_relationships, :source => :objects
  belongs_to :post_type, class_name: "CamaleonCms::PostType", foreign_key: :parent_id, inverse_of: :post_tags
  belongs_to :owner, class_name: PluginRoutes.static_system_info['user_model'].presence || 'CamaleonCms::User', foreign_key: :user_id
end
