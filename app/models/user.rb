class UniqValidatorUser < ActiveModel::Validator
  def validate(record)
    record.errors[:base] << "#{I18n.t('admin.users.message.requires_different_username')}" if User.where(username: record.username).where.not(id: record.id).where("users.site_id" => record.site_id).size > 0
    record.errors[:base] << "#{I18n.t('admin.users.message.requires_different_email')}" if User.where(email: record.email).where.not(id: record.id).where("users.site_id" => record.site_id).size > 0

  end
end

class User < ActiveRecord::Base
  include Metas
  include CustomFieldsRead
  # has_one :profile , :class_name => "Profile", :foreign_key => "user_id", dependent: :destroy
  attr_accessible :username, :role, :email, :parent_id, :last_login_at, :site_id, :password, :password_confirmation #, :profile_attributes
  #attr_accessor
  #accepts_nested_attributes_for :profile
  default_scope {order('users.role ASC')}
  #validates_uniqueness_of :username #, :unless => Proc.new { |a| a.auth_social.present? }
  #validates_uniqueness_of :email #, :unless => Proc.new { |a| a.auth_social.present? }

  validates :username, :presence => true
  validates :email, :presence => true, :format => { :with => /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i } #, :unless => Proc.new { |a| a.auth_social.present? }
  validates_with UniqValidatorUser

  has_secure_password #validations: :auth_social.nil?

  #validates :password, :confirmation => true,
  #          :unless => Proc.new { |a| a.password.blank? }
  before_create { generate_token(:auth_token) }
  before_save :before_saved
  before_create :before_saved
  after_create :set_all_sites
  before_destroy :reassign_posts
  # relations

  has_many :metas, ->{ where(object_class: 'User')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :user_relationships, class_name: "UserRelationship", foreign_key: :user_id, dependent: :destroy#,  inverse_of: :user
  has_many :term_taxonomies, foreign_key: :term_taxonomy_id, class_name: "TermTaxonomy", through: :user_relationships, :source => :term_taxonomies
  has_many :sites, foreign_key: :term_taxonomy_id, class_name: "Site", through: :user_relationships, :source => :term_taxonomies
  has_many :all_posts, class_name: "Post"
  #scopes
  scope :admin_scope, -> { where(:role => 'admin') }
  scope :actives, -> { where(:active => 1) }
  scope :not_actives, -> { where(:active => 0) }

  #vars
  STATUS = {0 => 'Active', 1=>'Not Active'}
  ROLE = { 'admin'=>'Administrator', 'client' => 'Client'}

  # return all posts of this user on site
  def posts(site)
    site.posts.where(user_id: self.id)
  end

  def self.meta_default
    {
        fields: {
            first_name: {type: 'text', label: 'First Name'},
            last_name: {type: 'text', label: 'Last Name'}
        }

    }.to_sym
  end


  def _id
    "#{self.role.upcase}-#{self.id}"
  end

  def fullname
    meta[:first_name].blank? ? self.username.titleize : "#{meta[:first_name]} #{meta[:last_name]}".titleize
  end

  def admin?
    role == 'admin'
  end

  def client?
    self.role == 'client'
  end

  def get_role(site)
    site.user_roles.where(slug: self.role).first
  end

  def set_meta_from_form(metas)
    metas.each do |key, value|
      self.metas.where({key: key}).update_or_create({value: value})
    end
  end

  def assign_site(site)
    self.user_relationships.where(term_taxonomy_id: site.id).first_or_create
  end

  def roleText
    User::ROLE[self.role]
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
    end while User.exists?(column => self[column])
  end

  def send_password_reset
    generate_token(:password_reset_token)
    self.password_reset_sent_at = Time.zone.now
    save!
  end



  private
  def create_profile
    self.build_profile if self.profile.nil?
  end

  def before_saved
    self.slug = self.username if self.slug.blank?
    self.slug = self.slug.to_s.parameterize
    self.role = PluginRoutes.system_info["default_user_role"] if self.role.blank?
  end

  def set_all_sites
    Site.all.each do |site|
      self.assign_site(site)
    end
  end

  # reassign all posts of this user to first admin
  # reassign all comments of this user to first admin
  # if doesn't exist any other administrator, this will cancel the user destroy
  def reassign_posts
    sites = Site.all
    sites.each do |site|
      u = site.users.admin_scope.where.not(id: self.id).first
      unless u.present?
        errors.add(:base, "The site \"#{site.name}\" must have at least one administrator")
        return false
      end
    end

    sites.each do |site|
      u = site.users.admin_scope.where.not(id: self.id).first
      self.posts(site).each do |p|
        p.update_column(:user_id, u.id)
        p.comments.where(user_id: self.id).each do |c|
          c.update_column(:user_id, u.id)
        end
      end
    end
  end

end
