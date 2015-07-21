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

  # install a plugin for current site
  # plugin_key: key of the plugin
  # return model of the plugin
  def plugin_install(plugin_key)
    plugin_model = current_site.plugins.where(slug: plugin_key).first_or_create!
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
  # if asset is present return full path to this asset
  # sample: <script src="<%= plugin_asset_path("my_plugin", "js/admin.js") %>"></script>
  def plugin_asset_path(plugin_key, asset = nil)
    "#{root_url(locale: nil)}assets/plugins/#{plugin_key}/assets/#{asset}"
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

      #self.class.helper h.constantize rescue ActionController::Base.helper(h.constantize)
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