# DEPRECATED MODEL, NOT USED ANY MORE
module CamaleonCms
  class PostRelationship < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}term_relationships"
    # attr_accessible :objectid, :term_taxonomy_id, :term_order
    default_scope -> { order(term_order: :asc) }

    belongs_to :post_type, class_name: 'CamaleonCms::PostType', foreign_key: :term_taxonomy_id, inverse_of: false,
                           optional: true
    belongs_to :post, lambda {
                        order("#{CamaleonCms::Post.table_name}.id DESC")
                      }, foreign_key: :objectid, inverse_of: :post_relationships, optional: true

    # callbacks
    after_create :update_count
    before_destroy :update_count

    private

    def update_count
      return if post_type.blank?

      post_type.update_column(:count, post_type.posts.size) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
