class AddGroupToCustomFieldValues < ActiveRecord::Migration
  def change
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}custom_fields_relationships", :group_number, :integer, default: 0
  end
end
