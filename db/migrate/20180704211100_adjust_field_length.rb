class AdjustFieldLength < CamaManager.migration_class
  def change
    change_column "#{PluginRoutes.static_system_info["db_prefix"]}posts", :title, :text
    remove_index "#{PluginRoutes.static_system_info["db_prefix"]}posts", :slug
    change_column "#{PluginRoutes.static_system_info["db_prefix"]}posts", :slug, :text
    add_index "#{PluginRoutes.static_system_info["db_prefix"]}posts", :slug, length: 1000
    change_column "#{PluginRoutes.static_system_info["db_prefix"]}term_taxonomy", :name, :text
  end
end
