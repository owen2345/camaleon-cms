class AddConfirmTokenToUsers < ActiveRecord::Migration
  def change
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}users", :confirm_email_token, :string, default: nil
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}users", :confirm_email_sent_at, :datetime, default: nil
    add_column "#{PluginRoutes.static_system_info["db_prefix"]}users", :is_valid_email, :boolean, default: true
  end
end
