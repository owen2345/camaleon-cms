class CamaleonCms::TermRelationship < ActiveRecord::Base
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}term_relationships"

  default_scope -> { order(term_order: :asc) }

  belongs_to :term_taxonomies, class_name: 'CamaleonCms::TermTaxonomy',
    foreign_key: :term_taxonomy_id, inverse_of: :term_relationships
  belongs_to :objects, -> { order("#{CamaleonCms::Post.table_name}.id DESC") },
    class_name: 'CamaleonCms::Post', foreign_key: :objectid, inverse_of: :term_relationships

  # callbacks
  after_create :update_count
  before_destroy :update_count

  private

  # update counter of post published items
  # TODO verify counter
  def update_count
	if term_taxonomies.present?
	  term_taxonomies.update_column('count', term_taxonomies.posts.published.size)
	end
  end
end
