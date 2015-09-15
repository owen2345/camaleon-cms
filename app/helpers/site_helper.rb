=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module SiteHelper
  # return current site or assign a site as a current site
  def current_site(site = nil)
    @current_site = site.decorate if site.present?
    return $current_site if defined?($current_site)
    return @current_site if defined?(@current_site)
    all_sites = Site.all
    if all_sites.size == 1
      site = all_sites.first.decorate
    else
      host = request.original_url.to_s.parse_domain
      if host == PluginRoutes.system_info["base_domain"]
        site = Site.first.decorate rescue nil
      else
        s = [host]
        s << request.subdomain if request.subdomain.present?
        site = Site.where(slug: s).first.decorate rescue nil
      end
    end
    puts "============================ Please define the $current_site = Site.first.decorate " unless site.present?
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


  # load all custom models customized by plugins or templates in custom_models.rb
  def site_load_custom_models(site)
    PluginRoutes.enabled_apps(site).each{ |app|
      next unless app["path"].present?
      s = File.join(app["path"], "config", "custom_models.rb")
      eval(File.read(s)) if File.exist?(s)
    }
  end

  #################### ONLY FOR CONSOLE ####################
  # switch console sessions and redefine current for the console session
  # site: Site model used as current site
  # return nil
  def site_console_switch(site = nil)
    $current_site = site
    site_load_custom_models($current_site)
  end
end
