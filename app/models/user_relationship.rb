class UserRelationship < ActiveRecord::Base
  self.table_name = "user_relationships"
  attr_accessible :user_id, :term_taxonomy_id, :term_order, :active

  belongs_to :term_taxonomies, :class_name => "TermTaxonomy", foreign_key: :term_taxonomy_id, inverse_of: :user_relationships
  belongs_to :user, :class_name => "User", foreign_key: :user_id, inverse_of: :user_relationships


end
