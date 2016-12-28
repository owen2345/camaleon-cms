module CamaleonCms::HooksHelper
  include CamaleonCms::PluginsHelper
  
  # execute hooks for plugin_key with action name hook_key
  # non public method
  # plugin: plugin configuration (config.json)
  # hook_key: hook key
  # params: params for hook
  def hook_run(plugin, hook_key, params = nil)
    _do_hook(plugin, hook_key, params)
  end

  # execute all hooks from enabled plugins with key hook_key
  # non public method
  # hook_key: hook key
  # params: params for hook
  def hooks_run(hook_key, params = nil)
    PluginRoutes.enabled_apps(current_site).each do |plugin|
      _do_hook(plugin, hook_key, params)
    end
  end

  # skip hook function with name: hook_function_name
  def hook_skip(hook_function_name)
    @_hooks_skip << hook_function_name
  end

  private

  def _do_hook(plugin, hook_key, params =  nil)
    return if !plugin.present? || !plugin["hooks"].present? || !plugin["hooks"][hook_key].present?

    plugin["hooks"][hook_key].each do |hook|
      next if @_hooks_skip.present? && @_hooks_skip.include?(hook)
      begin
        if params.nil?
          send(hook)
        else
          send(hook, params)
        end
        Rails.logger.debug "Camaleon CMS - Hook \"#{hook_key}\" executed from dependency #{plugin['key'] rescue ''}".cama_log_style(:light_blue)
      rescue
        plugin_load_helpers(plugin)
        if params.nil?
          send(hook)
        else
          send(hook, params)
        end
      end
    end
  end
end
