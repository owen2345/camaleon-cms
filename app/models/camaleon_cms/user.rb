unless PluginRoutes.static_system_info['user_model'].present?
  class CamaleonCms::User < ActiveRecord::Base
    include CamaleonCms::UserMethods
    self.table_name = PluginRoutes.static_system_info["cama_users_db_table"] || "#{PluginRoutes.static_system_info["db_prefix"]}users"
    default_scope {order(role: :asc)}
    validates :username, :presence => true
    validates :email, :presence => true, :format => { :with => /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i } #, :unless => Proc.new { |a| a.auth_social.present? }
    has_secure_password

    def self.by_email(email)
      where(['lower(email) = ?', email.to_s.downcase])
    end

    def self.by_username(username)
      where(['lower(username) = ?', username.to_s.downcase])
    end
  end
end