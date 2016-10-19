
# DEPRECATED MODEL, NOT USED ANY MORE
class CamaleonCms::PostRelationship < ActiveRecord::Base
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}term_relationships"
  # attr_accessible :objectid, :term_taxonomy_id, :term_order
  default_scope ->{ order(term_order: :asc) }

  belongs_to :post_type, :class_name => "CamaleonCms::PostType", foreign_key: :term_taxonomy_id, inverse_of: :post_relationships
  belongs_to :posts, ->{ order("#{CamaleonCms::Post.table_name}.id DESC") }, :class_name => "CamaleonCms::Post", foreign_key: :objectid, inverse_of: :post_relationships, dependent: :destroy

  # callbacks
  after_create :update_count
  before_destroy :update_count

  private
  def update_count
    self.post_type.update_column('count', self.post_type.posts.size) if self.post_type.present?
  end

end
