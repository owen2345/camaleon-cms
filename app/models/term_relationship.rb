class TermRelationship < ActiveRecord::Base
  self.table_name = "term_relationships"
  attr_accessible :objectid, :term_taxonomy_id, :term_order
  default_scope ->{ order(term_order: :asc) }

  belongs_to :term_taxonomies, :class_name => "TermTaxonomy", foreign_key: :term_taxonomy_id, inverse_of: :term_relationships
  belongs_to :objects, ->{ order("posts.id DESC") }, :class_name => "Post", foreign_key: :objectid, inverse_of: :term_relationships

  # callbacks
  after_create :update_count
  before_destroy :update_count

  private
  def update_count
    self.term_taxonomies.update_column('count', self.term_taxonomies.posts.published.size) if self.term_taxonomies.present?
  end

end
