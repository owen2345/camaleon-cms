module CamaleonCms
  module SessionHelper
    # log in the user in to system
    # user: User model
    # remember_me: true/false (remember session permanently)
    # redirect_url (default nil): after initialized the session, this will be redirected to
    #   "redirect_url" if defined
    #   it doesn't redirect if redirect_url === false
    #   return to previous page if defined the cookie['return_to'], or login
    #     url received extra param: return_to=https://mysite.com
    def login_user(user, remember_me = false, redirect_url = nil, rotate_session: true)
      # Rotate the session on a genuine sign-in (H6): a fresh session drops any state left behind by a
      # previous occupant of a shared browser — notably an impersonation parent_auth_token, which
      # session_back_to_parent would otherwise restore on logout, escalating the new user to admin.
      # Impersonation manages that token itself and passes rotate_session: false so this does not wipe it.
      reset_session if rotate_session

      c = { value: [user.auth_token, request.user_agent, request.ip], expires: 24.hours.from_now }
      c[:domain] = :all if PluginRoutes.system_info['users_share_sites'].present? && CamaleonCms::Site.count > 1
      c[:expires] = 1.month.from_now if remember_me

      # fix to overwrite a cookie
      cookies.delete(:auth_token, domain: :all)
      cookies.delete(:auth_token)

      user.update({ last_login_at: Time.zone.now })
      cookies[:auth_token] = c

      # user redirection
      flash[:notice] = t('camaleon_cms.admin.login.message.success', locale: current_site.get_admin_language)
      return if redirect_url == false

      if redirect_url.present?
        # Host-check the explicit redirect_url too: after_login hooks and downstream plugins pass
        # caller-controlled destinations here (e.g. a return_to cookie), so it gets the same open-redirect
        # guard as the return_to cookie branch below rather than being followed verbatim.
        redirect_to safe_redirect_url(redirect_url) || cama_admin_dashboard_path
      elsif (return_to = cookies.delete(:return_to)).present?
        redirect_to safe_redirect_url(return_to) || cama_admin_dashboard_path
      else
        redirect_to cama_admin_dashboard_path
      end
    end

    # login a user using username and password
    # return boolean: true => authenticated, false => authentication failed
    def login_user_with_password(username, password)
      # Custom class finder: usernames are stored downcased, so the lookup must
      # lower-case both sides regardless of DB collation.
      user = current_site.users.find_by_username(username) # rubocop:disable Rails/DynamicFindBy
      r = { user: user, params: params, password: password, captcha_validate: true }
      hooks_run('user_before_login', r)
      user&.authenticate(password)
    end

    # User registration.
    #
    # user_data must contain:
    # - first_name
    # - email
    # - username
    # - password
    # - password_confirmation
    def cama_register_user(user_data, meta)
      user = current_site.users.new(user_data)
      r = { user: user, params: params }
      hook_run('user_before_register', r)

      if current_site.security_user_register_captcha_enabled? && !cama_captcha_verified?
        { result: false, type: :captcha_error, message: t('camaleon_cms.admin.users.message.error_captcha'),
          user: user }
      elsif user.save
        user.set_metas(meta)
        message = if current_site.need_validate_email?
                    t('camaleon_cms.admin.users.message.created_pending_validate_email')
                  else
                    t('camaleon_cms.admin.users.message.created')
                  end
        r = { user: user, message: message, redirect_url: cama_admin_login_path }
        hooks_run('user_after_register', r)
        { result: true, message: r[:message], redirect_url: r[:redirect_url], user: user }
      else
        { result: false, type: :no_saved, user: user }
      end
    end

    # check if current host is heroku
    def cama_on_heroku?
      ENV.keys.any? { |var_name| var_name.match(/(heroku|dyno)/i) }
    end

    # switch current session user into other (user)
    # after switched, this will be redirected to redirect_url or admin dashboard
    def session_switch_user(user, redirect_url = nil)
      return unless cama_sign_in?

      # Start impersonation from a clean session (see login_user), then stash the admin's auth cookie.
      # The stash happens AFTER the reset and login_user is told not to rotate again, so the token
      # session_back_to_parent restores later survives this rotation (H6).
      parent_auth_token = cookies[:auth_token]
      reset_session
      session[:parent_auth_token] = parent_auth_token
      login_user(user, false, redirect_url, rotate_session: false)
    end

    # The admin who started the current impersonation, resolved from the stashed parent auth token
    # (same lookup as cama_current_user). Returns nil if there is no active impersonation or the stash
    # no longer resolves to a user (e.g. the admin rotated their token by changing their password).
    # Callers MUST re-authenticate this user before session_back_to_parent (H6 residual): the
    # impersonated session an admin holds is indistinguishable from one they abandon, so the admin's
    # password is the only proof that the person returning is the admin and not a later occupant.
    def cama_impersonation_parent_user
      token = session[:parent_auth_token].to_s.split('&').first
      return if token.blank?

      current_site.users_include_admins.find_by(auth_token: token)
    end

    # switch current session into parent session called by session_switch_user
    # after returned into parent session, this will be redirected to redirect_url or admin dashboard
    # SECURITY: only call this once the parent admin has been re-authenticated (see
    # Admin::SessionsController#back_to_parent and cama_impersonation_parent_user).
    def session_back_to_parent(redirect_url = nil)
      return unless cama_sign_in? && session[:parent_auth_token].present?

      cookies[:auth_token] = session[:parent_auth_token]
      session.delete(:parent_auth_token)
      redirect_to (redirect_url || cama_admin_dashboard_path), notice: 'Welcome back!'
    end

    # logout current user
    def cama_logout_user
      cookies.delete(:auth_token, domain: :all)
      cookies.delete(:auth_token, domain: nil)
      c_data = { value: nil, expires: 24.hours.ago }
      c_data[:domain] = :all if PluginRoutes.system_info['users_share_sites'].present? && CamaleonCms::Site.count > 1
      cookies[:auth_token] = c_data
      CurrentRequest.user = nil
      CurrentRequest.user_resolved = true # the cookie is gone; don't re-resolve to a stale user
      # Drop all server-side session state on logout (H6): a lingering impersonation parent_auth_token
      # must not survive to be restored into a later session on a shared browser.
      reset_session
      redirect_to safe_redirect_url(params[:return_to]) || cama_admin_login_path,
                  notice: t('camaleon_cms.admin.logout.message.closed')
    end

    # Check if the current user is already signed
    def cama_sign_in?
      !cama_current_user.nil?
    end

    alias signin? cama_sign_in?

    # return the role for the current user
    # if not logged in, then return 'public'
    def cama_current_role
      current_site.visitor_role
    end

    # return the current user logged in
    def cama_current_user
      # Honor an externally-set user, and memoize a nil resolution via user_resolved so a signed-out
      # request (or a present-but-stale auth cookie) is not re-resolved on every call (regression M16).
      return CurrentRequest.user if CurrentRequest.user || CurrentRequest.user_resolved

      CurrentRequest.user_resolved = true
      user = cama_calc_api_current_user # api current user...
      if user.nil? && cookie_auth_token_complete?
        user = current_site.users_include_admins.find_by(auth_token: user_auth_token_from_cookie).try(:decorate)
      end
      CurrentRequest.user = user
    end

    def cookie_auth_token_complete?
      cookie_split_auth_token&.size == 3
    end

    def cookie_split_auth_token
      cookies[:auth_token]&.split('&')
    end

    def user_auth_token_from_cookie
      cookie_split_auth_token.first
    end

    # check if a visitor was logged in
    # if the user was not logged in, then redirect to login url
    def cama_authenticate(redirect_uri = nil)
      params[:return_to] = redirect_uri
      return if cama_sign_in?

      flash[:error] = t('camaleon_cms.admin.login.please_login')
      cookies[:return_to] = if params[:return_to].present?
                              params[:return_to]
                            else
                              (request.get? && params[:controller] != 'admin/sessions' ? request.original_url : nil)
                            end
      redirect_to cama_admin_login_path
    end

    # return the session id
    def cama_get_session_id
      session[:autor] = 'Owen Peredo Diaz' if request.session_options[:id].blank?
      id = request.session_options[:id]
      id = id.public_id if id.instance_of?(::Rack::Session::SessionId)
      id
    end

    private

    # validate redirect url to prevent open redirect attacks: relative or same-host only,
    # host compared case-insensitively (RFC 3986); cross-site return_to on multisite is
    # deliberately unsupported — a sibling-site allowlist would be its own security change.
    # A passing absolute URL is emitted with the host in the request's canonical case, so
    # Rails' own case-sensitive open-redirect protection stays active without tripping on it.
    def safe_redirect_url(url)
      return if url.blank?

      uri = URI.parse(url)
      if uri.host.present?
        return unless uri.host.casecmp?(request.host)

        uri.host = request.host
        return uri.to_s
      end

      # A blank parsed host does not mean same-origin: a scheme (https:evil.com, javascript:...) or a
      # slash/backslash-led form (///evil.com, /\evil.com, and their %2f/%5c encodings) still sends a
      # browser off-site. Follow only a genuine same-origin path — one leading "/" then a normal path
      # character (audit: the ///evil.com open redirect).
      return unless uri.scheme.blank? && url.start_with?('/') && !url.match?(%r{\A/(?:[/\\]|%2f|%5c)}i)

      url
    rescue URI::InvalidURIError
      nil
    end

    # calculate the current user for API
    def cama_calc_api_current_user
      begin
        doorkeeper_token
      rescue NameError
        # hack, this method should be called from a context which has
        # doorkeeper_token defined
        return nil
      end
      return unless doorkeeper_token

      current_site.users_include_admins.find_by(id: doorkeeper_token.resource_owner_id).try(:decorate)
    end
  end
end
