unless PluginRoutes.static_system_info['user_model'].present?
  class CamaleonCms::User < ActiveRecord::Base
    include CamaleonCms::UserMethods
    self.table_name = PluginRoutes.static_system_info["cama_users_db_table"] || "#{PluginRoutes.static_system_info["db_prefix"]}users"
    # attr_accessible :username, :role, :email, :parent_id, :last_login_at, :site_id, :password, :password_confirmation, :first_name, :last_name #, :profile_attributes
    # attr_accessible :is_valid_email

    default_scope {order(role: :asc)}
    validates :username, :presence => true
    validates :email, :presence => true, :format => { :with => /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i } #, :unless => Proc.new { |a| a.auth_social.present? }
    has_secure_password #validations: :auth_social.nil?
  end
end