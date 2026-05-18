module CamaleonCms
  module HookLifecycleConcern
    extend ActiveSupport::Concern

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
  end
end
