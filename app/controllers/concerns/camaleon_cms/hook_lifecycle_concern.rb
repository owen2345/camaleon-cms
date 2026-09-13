module CamaleonCms
  # Controller side of hook dispatch. The dispatch itself lives in HooksHelper (single source of
  # truth), so the controller and view paths cannot drift apart; this concern adds the controller
  # lifecycle runners and overrides the two pieces a controller does differently: the skip list
  # honours a legacy @_hooks_skip ivar, and a plugin's helpers are included into the controller class.
  module HookLifecycleConcern
    extend ActiveSupport::Concern

    include CamaleonCms::HooksHelper

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

    def hook_skip_list
      state = camaleon_hooks_state
      return state[:hooks_skip] if state[:hooks_skip]

      # back-compat: legacy plugins/themes may seed @_hooks_skip directly on the
      # controller. Honored here (controller concern) only as initial input so the
      # shared view helper stays ivar-free.
      existing_hooks_skip = @_hooks_skip
      state[:hooks_skip] = existing_hooks_skip.is_a?(Array) ? existing_hooks_skip : []
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
