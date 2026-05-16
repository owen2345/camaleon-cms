if PluginRoutes.static_system_info['user_model'].blank?
  module CamaleonCms
    class User < CamaleonRecord
      include CamaleonCms::UserMethods

      self.table_name = PluginRoutes.static_system_info['cama_users_db_table'] ||
                        "#{PluginRoutes.static_system_info['db_prefix']}users"

      default_scope { order(role: :asc) }

      has_many :widgets, class_name: 'CamaleonCms::Widget::Main', dependent: :destroy,
                         inverse_of: :owner

      validates :username, presence: true
      # The following might be continued wit: , :unless => Proc.new { |a| a.auth_social.present? }
      validates :email, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }
      has_secure_password

      def self.find_by_email(email)
        find_by(['lower(email) = ?', email.to_s.downcase])
      end

      def self.find_by_username(username)
        find_by(['lower(username) = ?', username.to_s.downcase])
      end
    end
  end
end
