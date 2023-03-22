module CamaleonCms
  class TermRelationship < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}term_relationships"
    default_scope -> { order(term_order: :asc) }

    belongs_to :term_taxonomy, inverse_of: :term_relationships, required: false
    belongs_to :object, lambda {
                          order("#{CamaleonCms::Post.table_name}.id DESC")
                        }, class_name: 'CamaleonCms::Post', foreign_key: :objectid, inverse_of: :term_relationships, required: false

    # callbacks
    after_create :update_count
    before_destroy :update_count

    private

    # update counter of post published items
    # TODO verify counter
    def update_count
      term_taxonomy.update_column('count', term_taxonomy.posts.published.size) if term_taxonomy&.try(:posts)
    end
  end
end
