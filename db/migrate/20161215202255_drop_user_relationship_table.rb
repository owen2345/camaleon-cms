class DropUserRelationshipTable < CamaManager.migration_class
  def change
    drop_table "#{PluginRoutes.static_system_info["db_prefix"]}user_relationships"
  end
end
