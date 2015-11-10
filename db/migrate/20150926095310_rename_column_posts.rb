# change post structure to optimize query speed
class RenameColumnPosts < ActiveRecord::Migration
  def change
    remove_column "#{PluginRoutes.static_system_info["db_prefix"]}posts", :comment_count
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}posts", :post_order, :integer, default: 0
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}posts", :taxonomy_id, :integer, default: nil, index: true
    CamaleonCms::Post.all.each do |post|
      begin
        post_id = post.get_post_type_depre.id
        post.update_column("taxonomy_id", post_id)
        post_order = post.term_relationships.where("term_taxonomy_id = ?", post_id).first.term_order
        post.update_column("post_order", post_order)
      rescue
        # puts "**************** The following Post is invalid: #{post.inspect}"
      end
    end
  end
end
