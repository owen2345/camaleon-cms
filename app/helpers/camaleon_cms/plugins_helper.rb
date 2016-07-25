=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::PluginsHelper
  # load all plugins + theme installed for current site
  # METHOD IGNORED (is a partial solution to avoid load helpers and cache it for all sites)
  # this method try to load helpers for each request without caching
  def plugins_initialize(klass = nil)
    mod = Module.new
    PluginRoutes.enabled_apps(current_site).each{|plugin|
      next if !plugin.present? || !plugin["helpers"].present?
      plugin["helpers"].each do |h|
        mod.send :include, h.constantize
      end
    }
    (klass || self).send :extend, mod
  end

  # upgrade installed plugin in current site for a new version
  # plugin_key: key of the plugin
  # trigger hook "on_upgrade"
  # return model of the plugin
  def plugin_upgrade(plugin_key)
    plugin_model = current_site.plugins.where(slug: plugin_key).first!
    hook_run(plugin_model.settings, "on_upgrade", plugin_model)
    plugin_model.installed_version= plugin_model.settings["version"]
    plugin_model
  end

  # install a plugin for current site
  # plugin_key: key of the plugin
  # return model of the plugin
  def plugin_install(plugin_key)
    if PluginRoutes.plugin_info(plugin_key).nil?
      Rails.logger.info "=========== Plugin not found: #{plugin_key}"
    else
      plugin_model = current_site.plugins.where(slug: plugin_key).first_or_create!
      plugin_model.installed_version= plugin_model.settings["version"]
      return plugin_model if plugin_model.active?
      plugin_model.active
      PluginRoutes.reload
      # plugins_initialize(self)
      hook_run(plugin_model.settings, "on_active", plugin_model)
      plugin_model
    end
  end

  # uninstall a plugin from current site
  # plugin_key: key of the plugin
  # return model of the plugin
  def plugin_uninstall(plugin_key)
    plugin_model = current_site.plugins.where(slug: plugin_key).first_or_create!
    return plugin_model unless plugin_model.active?
    plugin_model.inactive
    PluginRoutes.reload
    # plugins_initialize(self)
    hook_run(plugin_model.settings, "on_inactive", plugin_model)
    plugin_model
  end

  # remove a plugin from current site
  # plugin_key: key of the plugin
  # return model of the plugin removed
  # DEPRECATED: PLUGINS AND THEMES CANNOT BE DESTROYED
  def plugin_destroy(plugin_key)
  end

  # return plugin full layout path
  # plugin_key: plugin name
  def plugin_layout(layout_name, plugin_key = nil)
    key = plugin_key || self_plugin_key(1)
    if PluginRoutes.plugin_info(key)["gem_mode"]
      "plugins/#{key}/layouts/#{layout_name}"
    else
      "plugins/#{key}/views/layouts/#{layout_name}"
    end
  end

  # return plugin full view path
  # plugin_key: plugin name
  def plugin_view(view_name, plugin_key = nil)
    if plugin_key.present? && plugin_key.include?("/") # fix for 1.x
      k = view_name
      view_name = plugin_key
      plugin_key = k
    end
    key = plugin_key || self_plugin_key(1)
    if PluginRoutes.plugin_info(key)["gem_mode"]
      "plugins/#{key}/#{view_name}"
    else
      "plugins/#{key}/views/#{view_name}"
    end
  end

  # return plugin full asset path
  # plugin_key: plugin name
  # asset: (String) asset name
  # sample: <script src="<%= plugin_asset_path("admin.js") %>"></script> => /assets/plugins/my_plugin/admin-54505620f.js
  # sample: <script src="<%= plugin_asset_path("admin.js", 'my_plugin') %>"></script> => /assets/plugins/my_plugin/admin-54505620f.js
  def plugin_asset_path(asset, plugin_key = nil)
    if plugin_key.present? && plugin_key.include?("/")
      return plugin_asset_url(plugin_key, asset || self_plugin_key(1))
    end
    key = plugin_key || self_plugin_key(1)
    if PluginRoutes.plugin_info(key)["gem_mode"]
      "plugins/#{key}/#{asset}"
    else
      "plugins/#{key}/assets/#{asset}"
    end
  end
  alias_method :plugin_asset, :plugin_asset_path
  alias_method :plugin_gem_asset, :plugin_asset_path

  # return the full url for asset of current plugin:
  # asset: (String) asset name
  # plugin_key: (optional) plugin name, default (current plugin caller to this function)
  # sample:
  #   plugin_asset_url("css/main.css") => return: http://myhost.com/assets/plugins/my_plugin/assets/css/main-54505620f.css
  def plugin_asset_url(asset, plugin_key = nil)
    key = plugin_key || self_plugin_key(1)
    p = PluginRoutes.plugin_info(key)["gem_mode"] ? "plugins/#{key}/#{asset}" : "plugins/#{key}/assets/#{asset}"
    begin
      asset_url(p)
    rescue NoMethodError => e
      p
    end
  end

  # auto load all helpers of this plugin
  def plugin_load_helpers(plugin)
    return if !plugin.present? || !plugin["helpers"].present?
    plugin["helpers"].each do |h|
      begin
        next if self.class.include?(h.constantize)
        self.class_eval do
          include h.constantize
        end
      rescue => e
        Rails.logger.info "---------------------------app loading error for #{h}: #{e.message}. Please check the plugins and themes presence"
      end
    end
  end

  # return plugin key for current plugin file (helper|controller|view)
  # index: internal control (ignored)
  def self_plugin_key(index = 0)
    f = caller[index]
    if f.include?('/apps/plugins/')
      key = f.split('/apps/plugins/').last.split("/").first
    elsif f.include?('/plugins/')
      key = f.split('/plugins/').last.split("/").first
    else
      key = f.split('/gems/').last.split("/").first
    end
    PluginRoutes.plugin_info(key)['key'] rescue raise("Not found plugin with key: #{key} or dirname: #{key}")
  end

  # method called only from files within plugins directory
  # return the plugin model for current site calculated according to the file caller location
  def current_plugin(plugin_key = nil)
    _key = plugin_key || self_plugin_key(1)
    cama_cache_fetch("current_plugin_#{_key}") do
      current_site.get_plugin(_key)
    end
  end

end
