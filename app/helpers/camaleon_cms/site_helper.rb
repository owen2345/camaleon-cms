module CamaleonCms::SiteHelper
  # return current site or assign a site as a current site
  def current_site(site = nil)
    @current_site = site.decorate if site.present?
    return $current_site if defined?($current_site)
    return @current_site if defined?(@current_site)
    if PluginRoutes.get_sites.size == 1
      site = CamaleonCms::Site.first.decorate rescue nil
    else
      host = [request.original_url.to_s.parse_domain]
      host << request.subdomain if request.subdomain.present?
      site = CamaleonCms::Site.where(slug: host).first.decorate rescue nil
    end
    r = {site: site, request: request};
    cama_current_site_helper(r) rescue nil
    Rails.logger.error 'Camaleon CMS - Please define your current site: $current_site = CamaleonCms::Site.first.decorate or map your domains: http://camaleon.tuzitio.com/documentation/category/139779-examples/how.html'.cama_log_style(:red) if !r[:site].present?
    @current_site = r[:site]
  end

  # return current theme model for current site
  def current_theme
    @_current_theme ||= current_site.get_theme.decorate
  end

  # get list templates files of current theme
  def cama_get_list_template_files(post_type)
    contained_files = []
    Dir[File.join(current_theme.settings["path"], "views", '*')].each do |path|
      f_name = File.basename(path)
      contained_files << f_name.split(".").first if f_name.include?('template_')
    end
    _args={tempates: contained_files, post_type: post_type}; hooks_run("post_get_list_templates", _args)
    _args[:tempates]
  end

  # get list layouts files of current theme
  # return an array of layouts for current theme
  def cama_get_list_layouts_files(post_type)
    contained_files = []
    Dir[File.join(current_theme.settings["path"], "views", "layouts", '*')].each do |path|
      f_name = File.basename(path)
      contained_files << f_name.split(".").first unless f_name.start_with?('_')
    end
    _args={layouts: contained_files, post_type: post_type}; hooks_run("post_get_list_layouts", _args)
    _args[:layouts]
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
    PluginRoutes.system_info["default_plugins"].each{|p| plugin_install(p) } # auto install plugins
    site_install_theme(theme_key)
    current_site(_s) if _s.present?
  end

  # install theme for current site
  def site_install_theme(key)
    #uninstall previous theme
    site_uninstall_theme()

    # new theme
    current_site.set_option('_theme', key)
    theme = PluginRoutes.theme_info(key)
    current_site.themes.update_all(status: "inactive")
    theme_model = current_site.themes.where(slug: key).first_or_create!{|t| t.name = theme[:name]; }
    theme_model.update(status: nil)
    hook_run(theme, "on_active", theme_model)
    PluginRoutes.reload
  end

  # uninstall current theme form current site
  def site_uninstall_theme()
    key = current_site.get_theme_slug
    theme = PluginRoutes.theme_info(key)
    theme_model = current_site.get_theme(key)
    hook_run(theme, "on_inactive", theme_model) if theme_model.present?
    # theme_model.destroy
  end

  # add host + port to args of the current site visited (only if the request is coming from console or tasks i.e. not web browser)
  # args: Hash
  # sample: {} will return {host: 'localhost', port: 3000}
  def cama_current_site_host_port(args)
    args[:host], args[:port] = current_site.try(:get_domain).to_s.split(':') if cama_is_test_request?
    args
  end

  # check if the request created by draper or request is not defined
  def cama_is_test_request?
    (request && defined?(ActionController::TestRequest) && request.is_a?(ActionController::TestRequest)) || !request
  end
end
