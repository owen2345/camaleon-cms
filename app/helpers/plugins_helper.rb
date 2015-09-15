=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module PluginsHelper
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
    plugin_model = current_site.plugins.where(slug: plugin_key).first_or_create!
    plugin_model.installed_version= plugin_model.settings["version"]
    return plugin_model if plugin_model.active?
    plugin_model.active
    PluginRoutes.reload
    # plugins_initialize(self)
    hook_run(plugin_model.settings, "on_active", plugin_model)
    plugin_model
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
  def plugin_destroy(plugin_key)
    # return
    plugin_model = current_site.plugins.where(slug: plugin_key).first_or_create
    if !plugin_can_be_deleted?(params[:id]) || true
      plugin_model.error = false
      plugin_model
    else
      hook_run(plugin_model.settings, "on_destroy", plugin_model)
      plugin_model.destroy
      PluginRoutes.destroy_plugin(params[:id])
      plugin_model.error = true
    end
    plugin_model
  end

  # return plugin full layout path
  # plugin_key: plugin name
  def plugin_layout(plugin_key, layout_name)
    "#{plugin_key}/views/layouts/#{layout_name}"
  end

  # return plugin full view path
  # plugin_key: plugin name
  def plugin_view(plugin_key, view_name)
    "#{plugin_key}/views/#{view_name}"
  end

  # return plugin full asset path
  # plugin_key: plugin name
  # asset: (String) asset name
  # sample: <script src="<%= plugin_asset_path("my_plugin", "js/admin.js") %>"></script> => /assets/plugins/my_plugin/assets/css/main-54505620f.css
  def plugin_asset_path(plugin_key, asset)
    p = "plugins/#{plugin_key}/assets/#{asset}"
    begin
      asset_url(p)
    rescue NoMethodError => e
      p
    end
  end

  # return the full url for asset of current plugin:
  # asset: (String) asset name
  # plugin_key: (optional) plugin name, default (current plugin caller to this function)
  # sample:
  #   plugin_asset_url("css/main.css") => return: http://myhost.com/assets/plugins/my_plugin/assets/css/main-54505620f.css
  def plugin_asset_url(asset, plugin_key = nil)
    p = "plugins/#{plugin_key || self_plugin_key}/assets/#{asset}"
    begin
      asset_url(p)
    rescue NoMethodError => e
      p
    end
  end

  # built asset file for current theme
  # plugin_name: (String) if nil, will be used self_plugin_key method
  # return (String), sample: plugin_asset("css/mains.css") => plugins/my_plugin/assets/css/main.css
  def plugin_asset(asset, plugin_name = nil)
    "themes/#{plugin_name || self_plugin_key }/assets/#{asset}"
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
        # flash.now[:error] = "app loading error for #{h}: #{e.message}. Please check the plugins and themes presence"
      end

      # self.class.helper h.constantize rescue ActionController::Base.helper(h.constantize)
    end
  end

  ############# admin helpers ##############
  # check if this plugin can be deleted
  def plugin_can_be_deleted?(key)
    c = 0
    Site.all.each do |site|
      c += site.plugins.where(slug: key).count
    end
    c == 0
  end

  # return plugin key for current plugin file (helper|controller|view)
  def self_plugin_key
    k = "app/apps/plugins/"
    f = caller.first
    f.split(k).last.split("/").first if f.include?(k)
  end

  # method called only from files within plugins directory
  # return the plugin model for current site
  def current_plugin
    current_site.get_plugin(self_plugin_key)
  end
end
