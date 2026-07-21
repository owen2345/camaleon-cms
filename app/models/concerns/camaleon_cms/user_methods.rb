module CamaleonCms
  module UserMethods
    extend ActiveSupport::Concern
    included do
      include CamaleonCms::Metas
      include CamaleonCms::CustomFieldsRead
      include CamaleonCms::CommonRelationships

      extend CamaleonCms::NormalizeAttrs

      validates(
        :username, uniqueness: { scope: [:site_id], case_sensitive: false,
                                 message: I18n.t(
                                   'camaleon_cms.admin.users.message.requires_different_username',
                                   default: 'Requires different username'
                                 ) }
      )
      validates(
        :email, uniqueness: { scope: [:site_id], case_sensitive: false,
                              message: I18n.t(
                                'camaleon_cms.admin.users.message.requires_different_email',
                                default: 'Requires different email'
                              ) }
      )

      # callbacks
      before_validation :cama_before_validation
      before_destroy :reassign_posts
      after_destroy :reassign_comments
      before_create { generate_token(:auth_token) }
      # invalidate sessions when changing password
      before_update { generate_token :auth_token if will_save_change_to_password_digest? }

      # relations
      has_many :all_posts, class_name: 'CamaleonCms::Post', foreign_key: :user_id, inverse_of: :owner,
                           dependent: :nullify
      has_many :all_comments, class_name: 'CamaleonCms::PostComment', dependent: :nullify

      belongs_to :site, class_name: 'CamaleonCms::Site', optional: true

      # scopes
      scope :admin_scope, -> { where(role: 'admin') }
      scope :actives, -> { where(active: 1) }
      scope :not_actives, -> { where(active: 0) }

      # vars
      STATUS = { 0 => 'Active', 1 => 'Not Active' }.freeze
      ROLE = { 'admin' => 'Administrator', 'client' => 'Client' }.freeze

      def self.decorator_class
        'CamaleonCms::UserDecorator'.constantize
      end
    end

    # return all posts of this user on site
    def posts(site)
      site.posts.where(user_id: id)
    end

    def fullname
      "#{first_name} #{last_name}".titleize
    end

    def admin?
      role == 'admin'
    end

    def client?
      role == 'client'
    end

    # return the UserRole Object of this user in Site
    def get_role(site)
      @_user_role ||= site.user_roles.where(slug: role).first
    end

    # Assign a new site for the current user
    def assign_site(site)
      update_column(:site_id, site.id) # rubocop:disable Rails/SkipsModelValidations
    end

    def sites
      if PluginRoutes.system_info['users_share_sites']
        CamaleonCms::Site.all
      else
        CamaleonCms::Site.where(id: site_id)
      end
    end

    def created
      created_at.strftime('%d/%m/%Y %H:%M')
    end

    def updated
      updated_at.strftime('%d/%m/%Y %H:%M')
    end

    # auth
    def generate_token(column)
      loop do
        self[column] = SecureRandom.urlsafe_base64
        break unless CamaleonCms::User.unscoped.exists?(column => self[column])
      end
    end

    def send_password_reset
      generate_token(:password_reset_token)
      self.password_reset_sent_at = Time.zone.now
      save!
    end

    def send_confirm_email
      generate_token(:confirm_email_token)
      self.confirm_email_sent_at = Time.zone.now
      save!
    end
    # end auth

    private

    def cama_before_validation
      self.role = PluginRoutes.system_info['default_user_role'] if role.blank?
      self.email = email.downcase if email.present?
      self.username = username.downcase if username.present?
    end

    # deprecated
    def set_all_sites
      nil
    end

    # reassign all posts of this user to first admin
    # reassign all comments of this user to first admin
    # if it doesn't exist any other administrator, this will cancel the user destroy
    def reassign_posts
      all_posts.each do |p|
        s = p.post_type.site
        u = s.users.admin_scope.where.not(id: id).first
        next if u.blank?

        p.update_column(:user_id, u.id) # rubocop:disable Rails/SkipsModelValidations
        p.comments.where(user_id: id).update_all(user_id: u.id) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    def reassign_comments
      all_comments.includes(post: { post_type: :site }).find_each do |comment|
        site = comment.post.post_type.site
        user = site.get_anonymous_user
        comment.update_column(:user_id, user.id) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
