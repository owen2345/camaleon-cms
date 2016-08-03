class CamaleonCms::UserRelationship < ActiveRecord::Base
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}user_relationships"
  # attr_accessible :user_id, :term_taxonomy_id, :term_order, :active

  belongs_to :term_taxonomies, :class_name => "CamaleonCms::TermTaxonomy", foreign_key: :term_taxonomy_id, inverse_of: :user_relationships
  belongs_to :user, :class_name => "CamaleonCms::User", foreign_key: :user_id, inverse_of: :user_relationships
end
