module SiteHelper

  # return current site or assign a site as a current site
  def current_site(site = nil)
    @current_site = site.decorate if site.present?
    return $current_site if defined?($current_site)
    return @current_site if defined?(@current_site)
    host = request.original_url.to_s.parse_domain
    if host == PluginRoutes.system_info["base_domain"]
      site = Site.first.decorate rescue nil
    else
      s = [host]
      s << request.subdomain if request.subdomain.present?
      site = Site.where(slug: s).first.decorate rescue nil
    end
    puts "============================ Please define the $current_site = Site.first.decorate " unless @current_site.present?
    @current_site = site
  end

  # initialize ability for current user
  def current_ability
    @current_ability ||= Ability.new(current_user, current_site)
  end

  # check if current site exist, if not, this will be redirected to main domain
  def site_check_existence()
    if !current_site.present?
      if (site = Site.first).present?
        base_domain = PluginRoutes.system_info["base_domain"]
        redirect_to root_url(host: base_domain.split(":").first, port: (base_domain.split(":")[1] rescue nil))
      else
        redirect_to admin_installers_path
      end
    end
  end

  # return current theme model for current site
  def current_theme
    @_current_theme ||= current_site.get_theme.decorate
  end

  # get list templates files
  def get_list_template_files
    base_path = Rails.root.join("app", "apps", 'themes', current_theme.slug, 'views')
    base_path = Pathname.new(base_path)
    contained_files = []
    Dir[File.join(base_path, '*.html.erb')].each do |full_path|
      path = Pathname.new(full_path).relative_path_from(base_path).to_s
      contained_files << path if path.include?('template_')
    end
    contained_files
  end

  # get locale language
  def current_locale
    I18n.locale.to_s
  end

  #***************** administration HELPERS ***********************
  # do common actions after site installation
  # theme_key: theme slug of the theme for site
  def site_after_install(site, theme_key = nil)
    theme_key ||= site.get_theme_slug
    _s = current_site
    current_site(site)
    PluginRoutes.system_info[:default_plugins].each{|p| plugin_install(p) } # auto install plugins
    site_install_theme(theme_key)
    current_site(_s)
  end

  # install theme for current site
  def site_install_theme(key)
    #uninstall previous theme
    site_uninstall_theme()

    # new theme
    current_site.set_option('_theme', key)
    theme = PluginRoutes.theme_info(key)
    theme_model = current_site.themes.where(slug: key).first_or_create!{|t| t.name = theme[:name]; }
    hook_run(theme, "on_active", theme_model)
    PluginRoutes.reload
  end

  # uninstall current theme form current site
  def site_uninstall_theme()
    key = current_site.get_theme_slug
    theme = PluginRoutes.theme_info(key)
    theme_model = current_site.get_theme(key)
    hook_run(theme, "on_inactive", theme_model) if theme_model.present?
    theme_model.destroy
  end

end
