module CamaleonCms
  module HooksHelper
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
      theme_slug = current_theme&.slug.presence || current_site.get_theme_slug
      PluginRoutes.enabled_apps(current_site, theme_slug).each do |plugin|
        _do_hook(plugin, hook_key, params)
      end

      # call all anonymous hooks
      PluginRoutes.get_anonymous_hooks(hook_key).each do |_hook|
        _hook.call(params)
      end
    end

    # skip hook function with name: hook_function_name
    def hook_skip(hook_function_name)
      hook_skip_list << hook_function_name
    end

    private

    def _do_hook(plugin, hook_key, params = nil)
      return if plugin.blank? || plugin['hooks'].blank? || plugin['hooks'][hook_key].blank?

      plugin['hooks'][hook_key].each do |hook|
        next if hook_skip_list.include?(hook)

        begin
          if params.nil?
            send(hook)
          else
            send(hook, params)
          end
          Rails.logger.debug "Camaleon CMS - Hook \"#{hook_key}\" executed from dependency #{begin
            plugin['key']
          rescue StandardError
            ''
          end}".cama_log_style(:light_blue)
        rescue StandardError
          plugin_load_helpers(plugin)
          if params.nil?
            send(hook)
          else
            send(hook, params)
          end
        end
      end
    end

    def hook_skip_list
      state = camaleon_hooks_state
      return state[:hooks_skip] if state[:hooks_skip]

      existing_hooks_skip = instance_variable_get(:@_hooks_skip)
      state[:hooks_skip] = existing_hooks_skip.is_a?(Array) ? existing_hooks_skip : []
    end

    def camaleon_hooks_state
      CurrentRequest.hooks_helper_state ||= {}
    end
  end
end
