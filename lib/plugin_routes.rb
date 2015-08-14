require 'json'
class PluginRoutes
  @@_vars = []
  # load plugin routes if it is enabled
  def self.load(env = "admin")
    plugins = all_enabled_plugins
    res = ""
    if env == "front"
      res << "namespace :plugins do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin["key"]}' do \n"
        res << "#{File.open(File.join(plugin["path"], "config", "routes_#{env}.txt")).read}\n" rescue ""
        res << "end\n"
      end
      res << "end\n"

    elsif env == "admin" # admin
      res << "scope 'admin', as: 'admin' do \n"
      res << "namespace :plugins do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin["key"]}' do \n"
        res << "#{File.open(File.join(plugin["path"], "config", "routes_#{env}.txt")).read}\n" rescue ""
        res << "end\n"
      end
      res << "end\n"
      res << "end\n"
    else # main
      plugins.each do |plugin|
        res << "#{File.open(File.join(plugin["path"], "config", "routes_#{env}.txt")).read}\n" rescue ""
      end
    end
    res + load_themes(env)
  end

  def self.load_themes(env = "admin")
    plugins = all_enabled_themes
    res = ""
    if env == "front"
      res << "namespace :themes do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin["key"]}' do \n"
        res << "#{File.open(File.join(plugin["path"], "config", "routes_#{env}.txt")).read}\n" rescue ""
        res << "end\n"
      end
      res << "end\n"

    elsif env == "admin" # admin
      res << "scope 'admin', as: 'admin' do \n"
      res << "namespace :themes do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin["key"]}' do \n"
        res << "#{File.open(File.join(plugin["path"], "config", "routes_#{env}.txt")).read}\n" rescue ""
        res << "end\n"
      end
      res << "end\n"
      res << "end\n"
    else # main
      plugins.each do |plugin|
        res << "#{File.open(File.join(plugin["path"], "config", "routes_#{env}.txt")).read}\n" rescue ""
      end
    end
    res
  end

  # return plugin information
  def self.plugin_info(plugin_key)
    return nil if plugin_key.start_with?(".") || !File.exist?(File.join(apps_dir, "plugins", plugin_key, "config", "config.json"))
    r = cache_variable("plugin_#{plugin_key}"); return r unless r.nil?
    res = JSON.parse(File.read(File.join(apps_dir, "plugins", plugin_key, "config", "config.json"))).with_indifferent_access
    res["key"] = plugin_key
    res["path"] = File.join(apps_dir, "plugins", plugin_key).to_s
    res["kind"] = "plugin"
    cache_variable("plugin_#{plugin_key}", res)
  end

  # return theme information
  # if theme_name is nil, the use current site theme
  def self.theme_info(theme_name)
    return nil if theme_name.start_with?(".") || !File.exist?(File.join(apps_dir, "themes", theme_name, "config", "config.json"))
    r = cache_variable("theme_#{theme_name}"); return r unless r.nil?
    dir = apps_dir
    res = JSON.parse(File.read(File.join(dir, "themes", theme_name, "config", "config.json"))).with_indifferent_access
    res["key"] = theme_name
    res["path"] = File.join(dir, "themes", theme_name).to_s
    res["kind"] = "theme"
    res["title"] = res["name"]
    cache_variable("theme_#{theme_name}", res)
  end

  # return system information
  def self.system_info
    r = cache_variable("system_info");  return r unless r.nil?
    res = {}
    res = JSON.parse(File.read(File.join($camaleon_engine_dir, "config", "system.json"))).with_indifferent_access if $camaleon_engine_dir.present?
    return cache_variable("system_info", res) unless File.exist?(system_file = File.join(apps_dir, "..", '..', "config", "system.json"))
    res = res.merge(JSON.parse(File.read(system_file)).with_indifferent_access).with_indifferent_access
    res["key"] = "system"
    res["path"] = ''
    res["kind"] = "system"
    res[:hooks] = {} unless res[:hooks].present?
    res[:hooks][:on_notification] = (res[:hooks][:on_notification] || []) + ["admin_system_notifications"]
    cache_variable("system_info", res)
  end

  # update a system value
  # key: attribute name
  # value: new value for attribute
  def self.system_info_set(key, val)
    ff = File.read(File.join(apps_dir, "..", '..', "config", "system.json"))
    File.open(File.join(apps_dir, "..", '..', "config", "system.json"), "w") do |f|
      f.write(ff.sub(/"#{key}": ?\"(.*)\"/, "\"#{key}\": \"#{val}\""))
    end
    self.reload
  end

  # reload routes
  def self.reload
    @@_vars.each {|v| class_variable_set("@@cache_#{v}", nil) }
    # WPRails::Application.routes_reloader.reload!
    Rails.application.reload_routes!
  end

  # return all enabled plugins []
  def self.enabled_plugins(site)
    r = cache_variable("enable_plugins_site_#{site.id}"); return r unless r.nil?
    res = []
    enabled_ps = site.plugins.active.pluck(:slug)
    all_plugins.each do |plugin|
      res << plugin if enabled_ps.include?(plugin["key"])
    end
    res = res.sort_by{|e| e[:position] || 10 }
    cache_variable("enable_plugins_site_#{site.id}", res)
  end

  # return all enabled apps for site (themes + system + plugins) []
  # theme_slug: current theme slug
  def self.enabled_apps(site, theme_slug = nil)
    theme_slug = theme_slug || site.get_theme_slug
    r = cache_variable("enabled_apps_#{site.id}_#{theme_slug}"); return r unless r.nil?
    res = [system_info()] + enabled_plugins(site) + [theme_info(theme_slug)]
    cache_variable("enabled_apps_#{site.id}_#{theme_slug}", res)
  end

  # return all enabled apps as []: system, themes, plugins
  def self.all_enabled_apps
    [system_info()] + all_enabled_themes + all_enabled_plugins
  end

  # return all enabled themes (a theme is enabled if at least one site is assigned)
  def self.all_enabled_themes
    r = cache_variable("all_enabled_themes"); return r unless r.nil?
    res = []
    get_sites.each do |site|
      i = theme_info(site.get_theme_slug)
      res << i if i.present?
    end
    cache_variable("all_enabled_themes", res)
  end

  # return all enabled plugins (a theme is enabled if at least one site has installed)
  def self.all_enabled_plugins
    r = cache_variable("all_enabled_plugins"); return r unless r.nil?
    res, enabled_ps = [], []
    get_sites.each { |site|  enabled_ps += site.plugins.active.pluck(:slug) }
    all_plugins.each do |plugin|
      if enabled_ps.include?(plugin["key"])
        res << plugin
      end
    end
    cache_variable("all_enabled_plugins", res)
  end

  # all helpers of enabled plugins for site
  def self.site_plugin_helpers(site)
    r = cache_variable("site_plugin_helpers"); return r unless r.nil?
    res = []
    enabled_apps(site).each do |settings|
      res += settings["helpers"] if settings["helpers"].present?
    end
    cache_variable("site_plugin_helpers", res)
  end

  # all helpers of enabled plugins
  def self.plugin_helpers
    r = cache_variable("plugins_helper"); return r unless r.nil?
    res = []
    all_enabled_apps.each do |settings|
      res += settings["helpers"] if settings["helpers"].present?
    end
    cache_variable("plugins_helper", res)
  end

  # destroy plugin
  def self.destroy_plugin(plugin_key)
    FileUtils.rm_r(Rails.root.join("app", "apps", "plugins", plugin_key)) rescue ""
    PluginRoutes.reload
  end

  # destroy theme
  def self.destroy_theme(theme_key)
    FileUtils.rm_r(Rails.root.join("app", "apps", "themes", theme_key)) rescue ""
    PluginRoutes.reload
  end

  def self.cache_variable(var_name, value=nil)
    @@_vars.push(var_name).uniq
    cache = class_variable_get("@@cache_#{var_name}") rescue nil
    return cache if value.nil?
    class_variable_set("@@cache_#{var_name}", value)
    value
  end

  # return all sites registered for Plugin routes
  def self.get_sites
    r = cache_variable("site_get_sites"); return r unless r.nil?
    res = {}
    begin
      res = Site.eager_load(:metas).order(term_group: :desc).all
    rescue
    end
    cache_variable("site_get_sites", res)
  end

  # return all locales for all sites joined by |
  def self.all_locales
    r = cache_variable("site_all_locales"); return r unless r.nil?
    res = []
    get_sites.each do |s|
      res += s.get_languages
    end
    cache_variable("site_all_locales", res.uniq.join("|"))
  end

  # draw "all" gems registered for the plugins or themes and camaleon gems
  def self.draw_gems
    res = []
    # recovering gem dependencies
    if camaleon_gem = get_gem('camaleon')
      res << File.read(File.join(camaleon_gem.gem_dir, "Gemfile")).gsub("source 'https://rubygems.org'", "")
    else
      gem_file = File.join(apps_dir, "..", "..", "lib", "Gemfile_camaleon")
      res << File.read(gem_file).gsub("source 'https://rubygems.org'", "") if File.exist?(gem_file)
    end

    p_dir = File.join(apps_dir, "plugins")
    if Dir.exist?(p_dir)
      Dir.entries(p_dir).select do |entry|
        f = File.join(apps_dir, "plugins", entry, "config", "Gemfile")
        res << File.read(f) if File.exist?(f)
      end
    end

    t_dir = File.join(apps_dir, "themes")
    if Dir.exist?(t_dir)
      Dir.entries(t_dir).select do |entry|
        f = File.join(apps_dir, "themes", entry, "config", "Gemfile")
        res << File.read(f) if File.exist?(f)
      end
    end
    res.join("\n")
  end

  # return apps directory path
  def self.apps_dir
    dir =  "#{File.dirname(__FILE__)}".split("/")
    dir.pop
    dir.join("/")+ '/app/apps'
  end

  def self.all_plugins
    r = cache_variable("all_plugins"); return r unless r.nil?
    res = []
    p_dir = File.join(apps_dir, "plugins")
    if Dir.exist?(p_dir)
      Dir.entries(p_dir).select do |entry|
        i = plugin_info(entry)
        res << i unless i.nil?
      end
    end
    cache_variable("all_plugins", res)
  end

  def self.all_themes
    r = cache_variable("all_themes"); return r unless r.nil?
    res = []
    t_dir = File.join(apps_dir, "themes")
    if Dir.exist?(t_dir)
      Dir.entries(t_dir).select do |entry|
        i = theme_info(entry)
        res << i unless i.nil?
      end
    end
    cache_variable("all_themes", res)
  end

  def self.all_apps
    all_plugins+all_themes
  end

  # check if a gem is available or not
  # Arguemnts:
  # name: name of the gem
  # return (Boolean) true/false
  def self.get_gem(name)
    Gem::Specification.find_by_name(name)
  rescue Gem::LoadError
    false
  rescue
    Gem.available?(name)
  end
end