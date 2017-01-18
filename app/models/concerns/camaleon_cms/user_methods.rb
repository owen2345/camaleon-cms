module CamaleonCms::UserMethods extend ActiveSupport::Concern
  included do
    include CamaleonCms::Metas
    include CamaleonCms::CustomFieldsRead

    validates_uniqueness_of :username, scope: [:site_id], case_sensitive: false, message: I18n.t('camaleon_cms.admin.users.message.requires_different_username', default: 'Requires different username')
    validates_uniqueness_of :email, scope: [:site_id], case_sensitive: false, message: I18n.t('camaleon_cms.admin.users.message.requires_different_email', default: 'Requires different email')

    # callbacks
    before_validation :cama_before_validation
    before_destroy :reassign_posts
    before_create { generate_token(:auth_token) }

    # relations
    has_many :metas, ->{ where(object_class: 'User')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
    has_many :all_posts, class_name: "CamaleonCms::Post"

    #scopes
    scope :admin_scope, -> { where(:role => 'admin') }
    scope :actives, -> { where(:active => 1) }
    scope :not_actives, -> { where(:active => 0) }

    #vars
    STATUS = {0 => 'Active', 1=>'Not Active'}
    ROLE = { 'admin'=>'Administrator', 'client' => 'Client'}

    def self.decorator_class
      'CamaleonCms::UserDecorator'.constantize
    end
  end

  # return all posts of this user on site
  def posts(site)
    site.posts.where(user_id: self.id)
  end

  def fullname
    "#{self.first_name} #{self.last_name}".titleize
  end

  def admin?
    role == 'admin'
  end

  def client?
    self.role == 'client'
  end

  # return the UserRole Object of this user in Site
  def get_role(site)
    @_user_role ||= site.user_roles.where(slug: self.role).first
  end

  # assign a new site for current user
  def assign_site(site)
    self.update_column(:site_id, site.id)
  end

  def sites
    if PluginRoutes.system_info["users_share_sites"]
      CamaleonCms::Site.all
    else
      CamaleonCms::Site.where(id: self.site_id)
    end
  end

  def created
    self.created_at.strftime('%d/%m/%Y %H:%M')
  end

  def updated
    self.updated_at.strftime('%d/%m/%Y %H:%M')
  end

  # auth
  def generate_token(column)
    begin
      self[column] = SecureRandom.urlsafe_base64
    end while CamaleonCms::User.exists?(column => self[column])
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
    self.role = PluginRoutes.system_info["default_user_role"] if self.role.blank?
    self.email = self.email.downcase if self.email.present?
    self.username = self.username.downcase if self.username.present?
  end

  # deprecated
  def set_all_sites
    return
  end

  # reassign all posts of this user to first admin
  # reassign all comments of this user to first admin
  # if doesn't exist any other administrator, this will cancel the user destroy
  def reassign_posts
    all_posts.each do |p|
      s = p.post_type.site
      u = s.users.admin_scope.where.not(id: self.id).first
      if u.present?
        p.update_column(:user_id, u.id)
        p.comments.where(user_id: self.id).each do |c|
          c.update_column(:user_id, u.id)
        end
      end
    end
  end
end