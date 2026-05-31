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

    # Back-compat: expose the affected user record as the `@user` controller ivar
    # for legacy templates/plugins. The helper methods themselves stay ivar-free;
    # these controller-concern overrides own the instance-variable bridging so the
    # shared view helpers never pollute the view context.
    def login_user_with_password(username, password)
      result = super
      @user = current_site.users.find_by(username: username)
      result
    end

    def cama_register_user(user_data, meta)
      result = super
      @user = result[:user] if result.is_a?(Hash) && result.key?(:user)
      result
    end

    # Redirect to login when the session has expired. Lives here because it is a
    # controller-only redirect concern (not a view helper).
    def auth_session_error
      redirect_to cama_root_path
    end
  end
end
