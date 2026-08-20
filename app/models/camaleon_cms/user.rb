if PluginRoutes.static_system_info['user_model'].blank?
  module CamaleonCms
    class User < CamaleonRecord
      include CamaleonCms::UserMethods

      self.table_name = PluginRoutes.static_system_info['cama_users_db_table'] ||
                        "#{PluginRoutes.static_system_info['db_prefix']}users"

      default_scope { order(role: :asc) }

      # No `dependent:` — a deleted user's widgets keep rendering; only the owner is gone.
      has_many :widgets, class_name: 'CamaleonCms::Widget::Main', # rubocop:disable Rails/HasManyOrHasOneDependent
                         inverse_of: :owner

      validates :username, presence: true
      # The following might be continued wit: , :unless => Proc.new { |a| a.auth_social.present? }
      validates :email, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }
      has_secure_password
      # Security (audit 2026-08-11 M15): has_secure_password only validates presence (on create) and the
      # 72-byte bcrypt maximum, so a trivially short password was accepted. Enforce a minimum length
      # whenever a password is actually set (create, reset, change). allow_blank leaves an update that
      # submits no password untouched (a blank field is not a change), and lets has_secure_password's own
      # presence check own the empty-on-create case.
      validates :password, length: { minimum: 8 }, allow_blank: true

      def self.find_by_email(email)
        find_by(['lower(email) = ?', email.to_s.downcase])
      end

      def self.find_by_username(username)
        find_by(['lower(username) = ?', username.to_s.downcase])
      end
    end
  end
end
