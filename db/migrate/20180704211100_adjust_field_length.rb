class AdjustFieldLength < CamaManager.migration_class
  def change
    post_table = CamaleonCms::Post.table_name
    change_column post_table, :title, :text
    remove_index(post_table, :slug) if index_exists?(post_table, :slug)
    change_column post_table, :slug, :text
    add_index post_table, :slug, length: 255
    change_column "#{PluginRoutes.static_system_info["db_prefix"]}term_taxonomy", :name, :text
  end
end
