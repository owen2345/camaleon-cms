class MoveFirstNameOfUsers < ActiveRecord::Migration
  def change
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}users", :first_name, :string
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}users", :last_name, :string
    CamaleonCms::User.all.each do |u|
      u.update_columns(first_name: u.get_meta('first_name'), last_name: u.get_meta('last_name'))
    end
  end
end
