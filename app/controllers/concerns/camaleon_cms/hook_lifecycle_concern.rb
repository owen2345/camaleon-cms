module CamaleonCms
  module HookLifecycleConcern
    extend ActiveSupport::Concern

    def hook_run(plugin, hook_key, params = nil)
      _do_hook(plugin, hook_key, params)
    end

    def hooks_run(hook_key, params = nil)
      theme_slug = current_theme&.slug.presence || current_site.get_theme_slug
      PluginRoutes.enabled_apps(current_site, theme_slug).each do |plugin|
        _do_hook(plugin, hook_key, params)
      end

      PluginRoutes.get_anonymous_hooks(hook_key).each do |_hook|
        _hook.call(params)
      end
    end

    def hook_skip(hook_function_name)
      hook_skip_list << hook_function_name
    end

    private

    def initialize_hook_skip_list
      hooks_skip = []
      CurrentRequest.hooks_helper_state ||= {}
      CurrentRequest.hooks_helper_state[:hooks_skip] = hooks_skip
      @_hooks_skip = hooks_skip
    end

    def run_hook_lifecycle(hook_name, payload = nil)
      payload.nil? ? hooks_run(hook_name) : hooks_run(hook_name, payload)
    end

    def run_app_before_load_hooks
      run_hook_lifecycle('app_before_load')
    end

    def run_app_after_load_hooks
      run_hook_lifecycle('app_after_load')
    end

    def _do_hook(plugin, hook_key, params = nil)
      return if plugin.blank? || plugin['hooks'].blank? || plugin['hooks'][hook_key].blank?

      plugin['hooks'][hook_key].each do |hook|
        next if hook_skip_list.include?(hook)

        # A plugin's helpers are included on demand, so a handler not yet defined loads them first;
        # one that stays undefined is skipped rather than failing the request. The handler itself
        # runs exactly once: a failure inside it is the caller's to see, never retried.
        plugin_load_helpers(plugin) unless respond_to?(hook, true)
        unless respond_to?(hook, true)
          Rails.logger.warn "Camaleon CMS - Hook \"#{hook_key}\": #{plugin['key']} registers #{hook}, " \
                            'which none of its helpers defines; skipped'
          next
        end

        params.nil? ? send(hook) : send(hook, params)
        executed = "Camaleon CMS - Hook \"#{hook_key}\" executed from dependency #{plugin['key']}"
        Rails.logger.debug executed.cama_log_style(:light_blue)
      end
    end

    def hook_skip_list
      state = camaleon_hooks_state
      return state[:hooks_skip] if state[:hooks_skip]

      # back-compat: legacy plugins/themes may seed @_hooks_skip directly on the
      # controller. Honored here (controller concern) only as initial input so the
      # shared view helper stays ivar-free.
      existing_hooks_skip = @_hooks_skip
      state[:hooks_skip] = existing_hooks_skip.is_a?(Array) ? existing_hooks_skip : []
    end

    def camaleon_hooks_state
      CurrentRequest.hooks_helper_state ||= {}
    end

    def plugin_load_helpers(plugin)
      return if plugin.blank? || plugin['helpers'].blank?

      plugin['helpers'].each do |h|
        next if self.class.include?(h.constantize)

        self.class.class_eval { include h.constantize }
      rescue StandardError => e
        Rails.logger.debug do
          "Camaleon CMS - App loading error for #{h}: #{e.message}. Please check the plugins and themes presence"
        end
      end
    end
  end
end
