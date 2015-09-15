=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Site < TermTaxonomy
  include SitePublic
  # attrs: [name, description, slug]
  default_scope { where(taxonomy: :site).reorder(term_group: :desc) }
  has_many :metas, ->{ where(object_class: 'Site')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :post_types, :class_name => "PostType", foreign_key: :parent_id, dependent: :destroy
  has_many :nav_menus, :class_name => "NavMenu", foreign_key: :parent_id, dependent: :destroy
  has_many :widgets, :class_name => "Widget::Main", foreign_key: :parent_id, dependent: :destroy
  has_many :sidebars, :class_name => "Widget::Sidebar", foreign_key: :parent_id, dependent: :destroy
  has_many :user_roles_rel, :class_name => "UserRole", foreign_key: :parent_id, dependent: :destroy
  has_many :custom_field_groups, :class_name => "CustomFieldGroup", foreign_key: :parent_id, dependent: :destroy
  # has_many :categories, :class_name => "Category", through: :post_types, :source => :categories , dependent: :destroy # root categories
  # has_many :post_tags, :class_name => "PostTag", through: :post_types, :source => :post_tags , dependent: :destroy, as: "posttag"
  has_many :term_taxonomies, :class_name => "TermTaxonomy", foreign_key: :parent_id

  #has_many :posts, through: :post_types, :source => :posts
  has_many :plugins, :class_name => "Plugin", foreign_key: :parent_id, dependent: :destroy
  has_many :themes, :class_name => "Theme", foreign_key: :parent_id, dependent: :destroy
  has_many :grid_templates, foreign_key: :parent_id, dependent: :destroy

  after_create :default_settings
  after_create :set_all_users
  after_create :set_default_user_roles
  after_save :update_routes
  before_destroy :destroy_site
  validates_uniqueness_of :slug, scope: :taxonomy

  def user_roles
    if PluginRoutes.system_info["users_share_sites"]
      Site.first.user_roles_rel
    else
      user_roles_rel
    end
  end

  # all post fix
  def posts
    Post.joins(:post_types).where("term_taxonomy.id" => self.post_types.pluck(:id)).order("term_relationships.term_order asc, posts.id DESC")
  end

  #select full_categories for the site, include all children categories
  def full_categories
   Category.where({term_group: self.id})
  end

  # all post_tags for this site
  def post_tags
    PostTag.includes(:post_type).where(post_type: self.post_types.pluck(:id))
  end

  # all main categories for this site
  def categories
    Category.includes(:post_type_parent).where(post_type_parent: self.post_types.pluck(:id))
  end

  # all posts for this site (faster mode)
  # alternative for Site.posts (no manage default order)
  # deprecated for select posts from scratch
  def posts2
    Post.joins(:post_types).where("term_taxonomy.id" => self.post_types.pluck(:id)).where("term_taxonomy.slug = ?", "post")
  end

  # return all languages configured by the admin
  # if it is empty, then return default locale
  def get_languages
    return @_languages if defined?(@_languages)
    l = get_meta("languages_site", [I18n.default_locale])
    @_languages = l.map { |x| x.to_sym } rescue [I18n.default_locale.to_sym]
  end

  # return current admin language configured for this site
  def get_admin_language
    options[:_admin_theme] || "en"
  end

  # set current admin language for this site
  def set_admin_language(language)
    set_option("_admin_theme", language)
  end

  # return current theme slug configured for this site
  # if theme was not configured, then return system.json defined
  def get_theme_slug
    options[:_theme] || PluginRoutes.system_info["default_template"]
  end

  # return theme model with slug theme_slug for this site
  # theme_slug: (optional) if it is null, this will return current theme for this site
  def get_theme(theme_slug = nil)
    self.themes.where(slug: (theme_slug || get_theme_slug), status: nil).first_or_create!
  end

  # return plugin model with slug plugin_slug
  def get_plugin(plugin_slug)
    self.plugins.where(slug: plugin_slug).first_or_create!
  end

  # assign user to this site
  def assign_user(user)
    user.assign_site(self)
  end

  # items per page to be listed on frontend
  def front_per_page
    get_option("front_per_page", 10)
  end

  # items per page to be listed on admin panel
  def admin_per_page
    get_option("admin_per_page", 10)
  end

  # frontend comments status for new comments on frontend
  def front_comment_status
    get_option("comment_status", "pending")
  end

  # auto create default user roles
  def set_default_user_roles(post_type = nil)
    user_role = self.user_roles.where({slug: 'admin', term_group: -1}).first_or_create({name: 'Administrator', description: 'Default roles admin'})
    if user_role.valid?
      d, m = {}, {}
      pts = self.post_types.all.pluck(:id)
      UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts }
      UserRole::ROLES[:manager].each { |value| m[value[:key]] = 1 }
      user_role.set_meta("_post_type_#{self.id}", d || {})
      user_role.set_meta("_manager_#{self.id}", m || {})
    end

    user_role = self.user_roles.where({slug: 'editor'}).first_or_create({name: 'Editor', description: 'Editor Role'})
    if user_role.valid?
      d = {}
      if post_type.present?
        d = user_role.meta[:_post_type] || {}
        UserRole::ROLES[:post_type].each { |value|
          value_old = d[value[:key]] || []
          d[value[:key]] = value_old + [post_type.id]
        }
      else
        pts = self.post_types.all.pluck(:id)
        UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts}
      end

      user_role.set_meta("_post_type_#{self.id}", d || {})
    end

    user_role = self.user_roles.where({slug: 'contributor'}).first_or_create({name: 'Contributor', description: 'Contributor Role'})
    if user_role.valid?
      d = {}
      if post_type.present?
        d = user_role.meta[:_post_type] || {}
        UserRole::ROLES[:post_type].each { |value|
          value_old = d[value[:key]] || []
          d[value[:key]] = value_old + [post_type.id] if value[:key].to_s == 'edit'
        }
      else
        pts = self.post_types.all.pluck(:id)
        UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts  if value[:key].to_s == 'edit'}
      end

      user_role.set_meta("_post_type_#{self.id}", d || {})
    end

    unless post_type.present?
      user_role = self.user_roles.where({slug: 'client', term_group: -1}).first_or_create({name: 'Client', description: 'Default roles client'})
      if user_role.valid?
        user_role.set_meta("_post_type_#{self.id}", {})
        user_role.set_meta("_manager_#{self.id}", {})
      end
    end

  end

  # return main site
  def self.main_site
    Site.first
  end

  # check if this site is the main site
  # main site is a site that doesn't have slug
  def main_site?
    @_is_default_site ||= (Site.first.id == self.id)
  end
  alias_method :is_default?, :main_site?

  # list all users of current site
  def users
    if PluginRoutes.system_info["users_share_sites"]
      User.where(site_id: -1)
    else
      User.where(site_id: self.id)#.where("site_id = ? or role = ?", self.id, 'admin')
    end
  end

  def users_include_admins
    if PluginRoutes.system_info["users_share_sites"]
      User.where(site_id: -1)
    else
      User.where("site_id = ? or role = ?", self.id, 'admin')
    end
  end

  # return upload directory for this site
  def upload_directory(inner_directory = nil)
    File.join(Rails.public_path, "/media/#{self.id}", inner_directory.to_s)
  end

  # return an available slug for a new post
  # slug: (String) possible slug value
  # sample: ("<!--:es-->features-1<!--:--><!--:en-->caract-1<!--:-->") | ("features")
  # return: (String) available slugs
  def get_valid_post_slug(slug)
    slugs = slug.translations
    if slugs.present?
      slugs.each do |k, v|
        slugs[k] = get_valid_post_slug(v)
      end
      slugs.to_translate
    else
      res = slug
      (1..9999).each do |i|
        break unless self.posts.find_by_slug(res)
        res = "#{slug}-#{i}"
      end
      res
    end
  end

  private
  # destroy all things before site destroy
  def destroy_site
    unless PluginRoutes.system_info["users_share_sites"]
      User.where(site_id: self.id).destroy_all
    end
    FileUtils.rm_rf(upload_directory) # destroy current media directory
  end

  def default_settings
    default_post_type =     [
        {
            name: 'Post',
            description: 'Posts',
            options: {
                has_category: true,
                has_tags: true,
                not_deleted: true,
                has_summary: true,
                has_content: true,
                has_comments: true,
                has_picture: true,
                has_template: true,
            }
        },
        {
            name: 'Page',
            description: 'Pages',
            options: {
                has_category: false,
                has_tags: false,
                not_deleted: true,
                has_summary: false,
                has_content: true,
                has_comments: false,
                has_picture: true,
                has_template: true,
            }
        }
    ]

    default_post_type.each do |pt|
      model_pt = self.post_types.create({
                                     name: pt[:name],
                                     slug: pt[:name].to_s.parameterize,
                                     description: pt[:description]
                                 })
      if model_pt.valid?
        model_pt.set_meta('_default', pt[:options])
        if pt[:options][:has_category]
          model_pt.default_category
        end
      end
    end

    # nav menus
    @sidebar  = self.sidebars.new({name: 'default sidebar', slug: 'default-sidebar'})
    @nav_menu = self.nav_menus.new({name: "Main Menu", slug: "main_menu"})
    @sidebar.save

    if @nav_menu.save
      self.post_types.all.each do |pt|
        if pt.slug == "post"
          title = "Sample Post"
          slug = 'sample-post'
          content = "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer pharetra ut augue in posuere. Nulla non malesuada dui. Sed egestas tortor ut purus tempor sodales. Duis non sollicitudin nulla, quis mollis neque. Integer sit amet augue ac neque varius auctor. Vestibulum malesuada leo leo, at semper libero efficitur nec. Etiam semper nisi ac nisi ullamcorper, sed tincidunt purus elementum. Mauris ac congue nibh. Quisque pretium eget leo nec suscipit. </p> <p> Vestibulum ultrices orci ut congue interdum. Morbi dolor nunc, imperdiet vel risus semper, tempor dapibus urna. Phasellus luctus pharetra enim quis volutpat. Integer tristique urna nec malesuada ullamcorper. Curabitur dictum, lectus id ultrices rhoncus, ante neque auctor erat, ut sodales nisi odio sit amet lorem. In hac habitasse platea dictumst. Quisque orci orci, hendrerit at luctus tristique, lobortis in diam. Curabitur ligula enim, rhoncus ut vestibulum a, consequat sit amet nisi. Aliquam bibendum fringilla ultrices. Aliquam erat volutpat. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; In justo mi, congue in rhoncus lobortis, facilisis in est. Nam et rhoncus purus. </p> <p> Sed sagittis auctor lectus at rutrum. Morbi ultricies felis mi, ut scelerisque augue facilisis eu. In molestie quam ex. Quisque ut sapien sed odio tempus imperdiet. In id accumsan massa. Morbi quis nunc ullamcorper, interdum enim eu, finibus purus. Vestibulum ac fermentum augue, at tempus ante. Aliquam ultrices, purus ut porttitor gravida, dui augue dignissim massa, ac tempor ante dolor at arcu. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Suspendisse placerat risus est, eget varius mi ultricies in. Duis non odio ut felis dapibus eleifend. In fringilla enim lobortis placerat efficitur. </p> <p> Nulla sodales faucibus urna, quis viverra dolor facilisis sollicitudin. Aenean ac egestas nibh. Nam non tortor eget nibh scelerisque fermentum. Etiam ornare, nunc ut luctus mollis, ante dolor consectetur augue, non scelerisque odio est a nulla. Nullam cursus egestas nulla, nec commodo nibh suscipit ut. Mauris ut felis sem. Aenean at mi at nisi dictum blandit sit amet at erat. Etiam eget lobortis tellus. Curabitur in commodo arcu, at vehicula tortor. </p>"
        else
          title = "Welcome"
          slug = 'welcome'
          content = "<p style='text-align: center;'><img width='155' height='155' src='http://camaleon.tuzitio.com/media/132/logo2.png' alt='logo' /></p><p><strong>Camaleon CMS</strong>&nbsp;is a free and open-source tool and a fexible content management system (CMS) based on <a href='rubyonrails.org'>Ruby on Rails 4</a>&nbsp;and MySQL.&nbsp;</p> <p>With Camaleon you can do the following:</p> <ul> <li>Create instantly a lot of sites&nbsp;in the same installation</li> <li>Manage your content information in several languages</li> <li>Extend current functionality by&nbsp;plugins (MVC structure and no more echo or prints anywhere)</li> <li>Create or install different themes for each site</li> <li>Create your own structure without coding anything (adapt Camaleon as you want&nbsp;and not you for Camaleon)</li> <li>Create your store and start to sell your products using our plugins</li> <li>Avoid web attacks</li> <li>Compare the speed and enjoy the speed of your new Camaleon site</li> <li>Customize or create your themes for mobile support</li> <li>Support&nbsp;more visitors at the same time</li> <li>Manage your information with a panel like wordpress&nbsp;</li> <li>All urls are oriented for SEO</li> <li>Multiples roles of users</li> </ul>"
        end
        user = self.users.admin_scope.first
        user = self.users.admin_scope.create({email: 'admin@local.com', username: 'admin', password: 'admin', password_confirmation: 'admin' }) unless user.present?
        post = pt.posts.create({title: title, slug: slug, content: content, user_id: user.id, status: 'published'})
        @nav_menu.append_menu_item({label: title, type: 'post', link: post.id})
      end
    end

    # default theme
    # self.themes.create(slug: PluginRoutes.system_info["default_template"])
    # self.set_option('_theme', PluginRoutes.system_info["default_template"])
  end

  def set_all_users
    User.all.each do |user|
      self.assign_user(user)
    end
  end

  # update all routes of the system
  def update_routes
    if self.id == Site.first.id
      PluginRoutes.system_info_set("base_domain", self.slug) if self.slug.present?
      # self.update_column("slug", "")
    end
    PluginRoutes.reload
  end

  def before_validating
    #overwriting/skipping term_taxonomy validations
  end
end
