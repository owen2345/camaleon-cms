class AddFeatureToPosts < CamaManager.migration_class
  def change
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}posts", :is_feature, :boolean, default: false
  end
end
