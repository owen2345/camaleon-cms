module CamaleonCms
  # Wires the session/auth and email helpers into the runtime controller stack.
  # Behaviour lives in the helper modules (single source of truth) so view and
  # controller contexts cannot drift apart.
  module SessionRuntimeConcern
    extend ActiveSupport::Concern

    include CamaleonCms::SessionHelper
    include CamaleonCms::EmailHelper
    include CamaleonCms::SessionCaptchaRuntimeConcern

    # When the host application does not define `current_user`, fall back to
    # Camaleon's own user lookup so `helper_method :current_user` keeps working.
    included do
      define_method(:current_user) { cama_current_user } unless ApplicationController.method_defined?(:current_user)
    end

    # Redirect to login when the session has expired. Lives here because it is a
    # controller-only redirect concern (not a view helper).
    def auth_session_error
      redirect_to cama_root_path
    end
  end
end
