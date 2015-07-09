module HooksHelper
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
    PluginRoutes.enabled_apps(current_site, current_theme.slug).each do |plugin|
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
        send(hook, params) unless params.nil?
        send(hook) if params.nil?
      rescue
        plugin_load_helpers(plugin)
        begin
          send(hook, params) unless params.nil?
          send(hook) if params.nil?
        rescue => e
          Rails.logger.info "--------------------------------------- error executing hook '#{hook_key}' for plugin '#{plugin["title"]}': #{e.message} --- #{e.backtrace.join("\n")}"
        end
      end
    end
  end
end