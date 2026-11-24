module CamaleonCms
  class Site < CamaleonCms::TermTaxonomy
    normalize_attrs(:description)

    include CamaleonCms::SiteDefaultSettings

    # attrs: [name, description, slug]
    attr_accessor :site_domain

    # Transient (never persisted): when default_settings auto-provisions the
    # administrator, it stashes the randomly generated plaintext password here so
    # the provisioning controller can surface it once. nil when no admin was minted
    # (e.g. a shared admin already existed). See harden-installer-default-admin.
    attr_accessor :generated_admin_password

    has_many :post_types, class_name: 'CamaleonCms::PostType', foreign_key: :parent_id, dependent: :destroy,
                          inverse_of: :site
    has_many :nav_menus, class_name: 'CamaleonCms::NavMenu', foreign_key: :parent_id, dependent: :destroy,
                         inverse_of: :site
    # inverse_of: false — this joins by term_group (the site id), while NavMenuItem#parent
    # reads parent_id (the menu id); an inverse here overwrites items' real menu parent.
    has_many :nav_menu_items, class_name: 'CamaleonCms::NavMenuItem', foreign_key: :term_group, inverse_of: false,
                              dependent: :destroy
    has_many :widgets, class_name: 'CamaleonCms::Widget::Main', foreign_key: :parent_id, dependent: :destroy,
                       inverse_of: :site
    has_many :sidebars, class_name: 'CamaleonCms::Widget::Sidebar', foreign_key: :parent_id, dependent: :destroy,
                        inverse_of: :site
    has_many :user_roles_rel, class_name: 'CamaleonCms::UserRole', foreign_key: :parent_id, dependent: :destroy,
                              inverse_of: :site
    has_many :custom_field_groups, class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :parent_id,
                                   dependent: :destroy, inverse_of: :parent
    has_many :term_taxonomies, class_name: 'CamaleonCms::TermTaxonomy', foreign_key: :parent_id, inverse_of: :parent,
                               dependent: :destroy

    has_many :posts, through: :post_types, source: :posts
    has_many :plugins, class_name: 'CamaleonCms::Plugin', foreign_key: :parent_id, dependent: :destroy,
                       inverse_of: :site
    has_many :themes, class_name: 'CamaleonCms::Theme', foreign_key: :parent_id, dependent: :destroy, inverse_of: :site
    has_many :public_media, -> { where(is_public: true) }, class_name: 'CamaleonCms::Media', foreign_key: :site_id,
                                                           dependent: :destroy, inverse_of: :site
    has_many :private_media, -> { where(is_public: false) }, class_name: 'CamaleonCms::Media', foreign_key: :site_id,
                                                             dependent: :destroy, inverse_of: :site

    after_create :default_settings
    after_create :set_default_user_roles
    # A new slug and a delete are stored only when the routes can be drawn. The site draws them on
    # trial in its transaction, and CamaleonCms::RouteDrawError rolls the change back. A create needs
    # no check of its own: each post type of the site reloads the routes there, with a trial.
    after_update :check_routes, if: proc { |obj| obj.saved_change_to_attribute?(:slug) }
    # The check of a delete runs before each other step of the delete. The delete removes the media
    # folder of the site, and a rollback does not bring that folder back.
    before_destroy :check_routes, prepend: true
    # A create, a delete and a new slug change the sites that PluginRoutes reads for the routes. The
    # site asks for the reload after the commit of its transaction. A reload in the transaction
    # reads data that a rollback removes, and PluginRoutes.get_sites keeps what it read.
    after_commit :refresh_routes, on: %i[create destroy]
    after_commit :refresh_routes_for_new_slug, on: :update
    after_commit :forget_main_site
    # PluginRoutes drops the data that it read in the transaction, and does the reload that waited.
    after_commit :settle_routes
    after_rollback :settle_routes_quietly

    before_destroy :destroy_site

    validates :slug, uniqueness: { scope: :taxonomy }

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
    # read through the meta memo, which a write on this instance, a reload and a copy keep current
    def get_languages
      get_meta('languages_site', [I18n.default_locale]).map(&:to_sym)
    rescue StandardError
      [I18n.default_locale.to_sym]
    end

    # return current admin language configured for this site
    def get_admin_language
      options[:_admin_theme] || 'en'
    end

    # Set the current admin language for this site
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
      themes.where(slug: theme_slug || get_theme_slug, status: nil).first_or_create!
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
    # The memo keeps no site that a read in a trial draw or in an open transaction gave: that site can
    # be data that is not committed.
    #
    # All threads share the memo. In a request, the query cache can hold the row from before a write of
    # another request. So the read for the memo uses no query cache.
    def self.main_site
      return @main_site if @main_site
      return CamaleonCms::Site.reorder(id: :asc).first if PluginRoutes.private_reads?

      @main_site = CamaleonCms::Site.uncached { CamaleonCms::Site.reorder(id: :asc).first }
    end

    # Makes main_site read the main site again. PluginRoutes calls it when it replaces or clears its
    # cached data, and a site calls it after its commit.
    def self.forget_main_site
      @main_site = nil
    end

    # check if this site is the main site
    # main site is a site that doesn't have slug
    def main_site?
      self.class.main_site == self
    end
    alias is_default? main_site?

    # list all users of current site
    def users
      return CamaleonCms::User.all if PluginRoutes.system_info['users_share_sites']

      CamaleonCms::User.where(site_id: id)
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
        slugs.each { |k, v| slugs[k] = get_valid_post_slug(v) }
        slugs.to_translate
      else
        res = slug
        (1..9999).each do |i|
          p = posts.find_by_slug(res) # rubocop:disable Rails/DynamicFindBy
          break if p.blank? || (p.present? && p.id == post_id)

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
      if user.blank?
        pass = "anonymous#{rand(9999)}"
        user = users.create({ email: 'anonymous_user@local.com', username: 'anonymous', password: pass,
                              password_confirmation: pass, first_name: 'Anonymous' })
      end
      user
    end

    # return the domain for current site
    # sample: mysite.com | sample.mysite.com
    # also, you can define custom domain for this site by: my_site.site_domain = 'my_site.com'
    # used for sites with different domains to call from console or task
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
    # In a PluginRoutes.reload_once block, the draw waits for the end of the block when it adds no route.
    def refresh_routes
      PluginRoutes.request_reload
    end

    def check_routes
      PluginRoutes.check_routes
    end

    def forget_main_site
      self.class.forget_main_site
    end

    def settle_routes
      PluginRoutes.settle_route_data
    end

    # An error of a reload after a rollback can hide the error that caused the rollback.
    def settle_routes_quietly
      PluginRoutes.settle_route_data(quiet: true)
    end

    # Asks for the reload when the list of PluginRoutes.get_sites does not hold the stored slug of
    # the site. For each row of a transaction, Rails runs the commit callbacks of one instance. That
    # instance can be another one than the instance that saved the new slug, and a later save of the
    # same instance reports no new slug. So the method reads the stored slug.
    #
    # The routes also hold the slug of the main site, as their default host. So the main site asks
    # for the reload too when the last reload drew another default host than its stored slug. A
    # list that is not loaded holds no old slug. With no such list and no such host, the method
    # reads no slug and asks for no reload.
    def refresh_routes_for_new_slug
      sites = PluginRoutes.loaded_sites
      drawn_host = drawn_host_of_main_site
      return if sites.nil? && drawn_host.nil?

      stored_slug = self.class.where(id: id).pick(:slug)
      return refresh_routes if drawn_host && drawn_host != stored_slug

      return if sites.nil?

      cached = sites.find { |site| site.id == id }
      refresh_routes unless cached && cached.slug == stored_slug
    end

    # The default host of the last reload when this site is the main site, else nil.
    def drawn_host_of_main_site
      host = PluginRoutes.drawn_default_host
      host if host && main_site?
    end

    def before_validating
      slug = self.slug
      slug = name if slug.blank?
      self.name = slug if name.blank?
      self.slug = slug.to_s.try(:downcase)
    end
  end
end
