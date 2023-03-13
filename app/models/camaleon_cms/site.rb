module CamaleonCms
  class Site < CamaleonCms::TermTaxonomy
    include CamaleonCms::SiteDefaultSettings

    # attrs: [name, description, slug]
    attr_accessor :site_domain

    default_scope { where(taxonomy: :site).reorder(term_group: :desc) }

    has_many :post_types, class_name: 'CamaleonCms::PostType', foreign_key: :parent_id, dependent: :destroy
    has_many :nav_menus, class_name: 'CamaleonCms::NavMenu', foreign_key: :parent_id, dependent: :destroy,
                         inverse_of: :site
    has_many :nav_menu_items, class_name: 'CamaleonCms::NavMenuItem', foreign_key: :term_group
    has_many :widgets, class_name: 'CamaleonCms::Widget::Main', foreign_key: :parent_id, dependent: :destroy
    has_many :sidebars, class_name: 'CamaleonCms::Widget::Sidebar', foreign_key: :parent_id, dependent: :destroy
    has_many :user_roles_rel, class_name: 'CamaleonCms::UserRole', foreign_key: :parent_id, dependent: :destroy
    has_many :custom_field_groups, class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :parent_id,
                                   dependent: :destroy
    has_many :term_taxonomies, class_name: 'CamaleonCms::TermTaxonomy', foreign_key: :parent_id

    has_many :posts, through: :post_types, source: :posts
    has_many :plugins, class_name: 'CamaleonCms::Plugin', foreign_key: :parent_id, dependent: :destroy
    has_many :themes, class_name: 'CamaleonCms::Theme', foreign_key: :parent_id, dependent: :destroy
    has_many :public_media, -> { where(is_public: true) },
             class_name: 'CamaleonCms::Media', foreign_key: :site_id, dependent: :destroy
    has_many :private_media, -> { where(is_public: false) },
             class_name: 'CamaleonCms::Media', foreign_key: :site_id, dependent: :destroy

    after_create :default_settings
    after_create :set_default_user_roles
    after_save :refresh_routes, if: proc { |obj| obj.saved_change_to_attribute?(:slug) }

    before_destroy :destroy_site
    after_destroy :refresh_routes

    validates_uniqueness_of :slug, scope: :taxonomy

    # all user roles for this site
    def user_roles
      if PluginRoutes.system_info['users_share_sites']
        CamaleonCms::Site.main_site.user_roles_rel
      else
        user_roles_rel
      end
    end

    # select full_categories for the site, include all children categories
    def full_categories
      CamaleonCms::Category.where(site_id: id)
    end

    # all post_tags for this site
    def post_tags
      CamaleonCms::PostTag.includes(:post_type).where(post_type: post_types.pluck(:id))
    end

    # all main categories for this site
    def categories
      CamaleonCms::Category.includes(:post_type_parent).where(post_type_parent: post_types.pluck(:id))
    end

    # return all languages configured by the admin
    # if it is empty, then return default locale
    def get_languages
      return @_languages if defined?(@_languages)

      l = get_meta('languages_site', [I18n.default_locale])
      @_languages = begin
        l.map(&:to_sym)
      rescue StandardError
        [I18n.default_locale.to_sym]
      end
    end

    # return current admin language configured for this site
    def get_admin_language
      options[:_admin_theme] || 'en'
    end

    # set current admin language for this site
    def set_admin_language(language)
      set_option('_admin_theme', language)
    end

    # return current theme slug configured for this site
    # if theme was not configured, then return system.json defined
    def get_theme_slug
      options[:_theme] || PluginRoutes.system_info['default_template']
    end

    # return theme model with slug theme_slug for this site
    # theme_slug: (optional) if it is null, this will return current theme for this site
    def get_theme(theme_slug = nil)
      themes.where(slug: (theme_slug || get_theme_slug), status: nil).first_or_create!
    end

    # return plugin model with slug plugin_slug
    def get_plugin(plugin_slug)
      plugins.where(slug: plugin_slug).first_or_create!
    end

    # assign user to this site
    def assign_user(user)
      user.assign_site(self)
    end

    # items per page to be listed on frontend
    def front_per_page
      get_option('front_per_page', 10)
    end

    # items per page to be listed on admin panel
    def admin_per_page
      get_option('admin_per_page', 10)
    end

    # frontend comments status for new comments on frontend
    def front_comment_status
      get_option('comment_status', 'pending')
    end

    # security: user register form show captcha?
    def security_user_register_captcha_enabled?
      get_option('security_captcha_user_register', false) == true
    end

    # check if current site permit capctha for anonymous comments
    def is_enable_captcha_for_comments?
      get_option('enable_captcha_for_comments', false)
    end

    def need_validate_email?
      get_option('need_validate_email', false) == true
    end

    # return main site
    def self.main_site
      @main_site ||= CamaleonCms::Site.reorder(id: :asc).first
    end

    # check if this site is the main site
    # main site is a site that doesn't have slug
    def main_site?
      self.class.main_site == self
    end
    alias is_default? main_site?

    # list all users of current site
    def users
      if PluginRoutes.system_info['users_share_sites']
        CamaleonCms::User.all
      else
        CamaleonCms::User.where(site_id: id)
      end
    end
    alias users_include_admins users

    # return upload directory for this site (deprecated for cloud support)
    def upload_directory(inner_directory = nil)
      File.join(Rails.public_path, "/media/#{PluginRoutes.static_system_info['media_slug_folder'] ? slug : id}",
                inner_directory.to_s)
    end

    # return the directory name where to upload file for this site
    def upload_directory_name
      (PluginRoutes.static_system_info['media_slug_folder'] ? slug : id).to_s
    end

    # return an available slug for a new post
    # slug: (String) possible slug value
    # post_id: (integer, optional) current post id
    # sample: ("<!--:es-->features-1<!--:--><!--:en-->caract-1<!--:-->") | ("features")
    # return: (String) available slugs
    def get_valid_post_slug(slug, post_id = nil)
      slugs = slug.translations
      if slugs.present?
        slugs.each do |k, v|
          slugs[k] = get_valid_post_slug(v)
        end
        slugs.to_translate
      else
        res = slug
        (1..9999).each do |i|
          p = posts.find_by_slug(res)
          break if !p.present? || (p.present? && p.id == post_id)

          res = "#{slug}-#{i}"
        end
        res
      end
    end

    # check if current site is active or not
    def is_active?
      status.blank? || status == 'active'
    end

    # check if current site is active or not
    def is_inactive?
      status == 'inactive'
    end

    # check if current site is in maintenance or not
    def is_maintenance?
      status == 'maintenance'
    end

    # return the anonymous user
    # if the anonymous user not exist, will create one
    def get_anonymous_user
      user = users.where(username: 'anonymous').first
      unless user.present?
        pass = "anonymous#{rand(9999)}"
        user = users.create({ email: 'anonymous_user@local.com', username: 'anonymous', password: pass,
                              password_confirmation: pass, first_name: 'Anonymous' })
      end
      user
    end

    # return the domain for current site
    # sample: mysite.com | sample.mysite.com
    # also, you can define custom domain for this site by: my_site.site_domain = 'my_site.com' # used for sites with different domains to call from console or task
    def get_domain
      @site_domain || (if main_site?
                         slug
                       else
                         (slug.include?('.') ? slug : "#{slug}.#{Cama::Site.main_site.slug}")
                       end)
    end

    private

    # destroy all things before site destroy
    def destroy_site
      CamaleonCms::User.where(site_id: id).destroy_all unless PluginRoutes.system_info['users_share_sites']
      FileUtils.rm_rf(File.join(Rails.public_path, "/media/#{upload_directory_name}")) # destroy current media directory
      users.destroy_all unless PluginRoutes.system_info['users_share_sites'] # destroy all users assigned fot this site
    end

    # assign all users to this new site
    # DEPRECATED
    def set_all_users
      nil
    end

    # update all routes of the system
    # reload system routes for this site
    def refresh_routes
      PluginRoutes.reload
    end

    def before_validating
      slug = self.slug
      slug = name if slug.blank?
      self.name = slug if name.blank?
      self.slug = slug.to_s.try(:downcase)
    end
  end
end
