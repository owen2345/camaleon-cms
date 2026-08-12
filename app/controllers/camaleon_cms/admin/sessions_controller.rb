module CamaleonCms
  module Admin
    class SessionsController < CamaleonCms::CamaleonController
      skip_before_action :cama_authenticate, raise: false
      before_action :before_hook_session
      after_action :after_hook_session
      before_action :verificate_register_permission, only: [:register]
      layout 'camaleon_cms/login'

      # you can pass return_to as a param (mysite.com/admin/login?return_to=my-url) and
      # this will be used after user logged in
      def login
        return cama_safe_redirect(params[:return_to], cama_admin_dashboard_path) if signin?

        cookies[:return_to] = params[:return_to] if params[:return_to].present?
        @user ||= current_site.users.new

        render 'login'
      end

      def login_post
        return if cama_halt_when_login_locked_out('login')

        data_user = user_permit_data
        # Custom class finder (not the dynamic finder): usernames are stored downcased,
        # so the lookup must lower-case both sides regardless of DB collation.
        @user = current_site.users.find_by_username(data_user[:username]) # rubocop:disable Rails/DynamicFindBy
        captcha_validate = captcha_verify_if_under_attack('login')
        r = { user: @user, params: params, password: data_user[:password], captcha_validate: captcha_validate,
              stop_process: false }
        hooks_run('user_before_login', r)
        return if r[:stop_process] # permit to redirect for data completion

        if captcha_validate && @user&.authenticate(data_user[:password])
          # Email validation if is necessary
          if @user.is_valid_email? || !current_site.need_validate_email?
            cama_captcha_reset_attack('login')
            r = { user: @user, redirect_to: params[:format] == 'json' ? false : nil }
            hooks_run('after_login', r)
            # An after_login hook may set r[:allow_external_redirect] to vouch for an off-site r[:redirect_to]
            # (SSO/payment); without it the destination is same-host/allowlist-only. See login_user.
            login_user(@user, params[:remember_me].present?, r[:redirect_to],
                       allow_external: r[:allow_external_redirect].present?)
            render(json: flash.discard.to_hash) if params[:format] == 'json'
            return
          else
            flash[:error] = t('camaleon_cms.admin.login.message.email_not_validated')
            @user = current_site.users.new(data_user)
            login if params[:format] != 'json'
          end
        else
          cama_captcha_increment_attack('login')
          flash[:error] = if captcha_validate
                            t('camaleon_cms.admin.login.message.fail')
                          else
                            t('camaleon_cms.admin.login.message.invalid_caption')
                          end
          @user = current_site.users.new(data_user)
          login if params[:format] != 'json'
        end
        render(json: flash.discard.to_hash) if params[:format] == 'json'
      end

      def logout
        # While impersonating, the ordinary Logout link must not silently hand the admin account back
        # to whoever holds the session — returning to the parent now requires the admin's password
        # (see #back_to_parent). `?full=1` forces a real logout of the impersonated session instead.
        if session[:parent_auth_token].present? && cama_sign_in? && params[:full].blank?
          redirect_to cama_admin_back_to_parent_path
        else
          cama_logout_user
        end
      end

      # Re-authenticate the impersonating admin before restoring their session (H6 residual). Reachable
      # only while an impersonation is active; a GET renders the confirmation form, a POST checks the
      # admin's password and only then returns to the parent session.
      def back_to_parent
        return redirect_to(cama_admin_login_path) unless session[:parent_auth_token].present? && cama_sign_in?

        @parent_user = cama_impersonation_parent_user
        # A stash that no longer resolves to a user — or resolves to an account with no password
        # digest, which #authenticate would raise on and which cannot prove the holder is the admin —
        # cannot be returned to; fail closed and end the session.
        return cama_logout_user if @parent_user.blank? || @parent_user.password_digest.blank?

        @impersonated_user = cama_current_user
        if request.post?
          return if cama_halt_when_login_locked_out('back_to_parent')

          # Failed guesses feed the login form's attack counter (same 'login' key), so this endpoint is
          # not an unthrottled oracle for the admin password: past the threshold a captcha is also
          # required, and because the parent stash lives in this same session, resetting the counter
          # (new session / full logout) destroys the stash being attacked.
          captcha_validate = captcha_verify_if_under_attack('login')
          if captcha_validate && @parent_user.authenticate(params[:password].to_s)
            cama_captcha_reset_attack('login')
            return session_back_to_parent(cama_admin_dashboard_path)
          end

          cama_captcha_increment_attack('login')
          flash.now[:error] = if captcha_validate
                                t('camaleon_cms.admin.login.message.reauth_failed',
                                  default: 'Incorrect password. Please try again.')
                              else
                                t('camaleon_cms.admin.login.message.invalid_caption')
                              end
        end
        render 'back_to_parent'
      end

      def forgot
        @user = current_site.users.new
        # get form reset password
        if params[:h].present?
          # Look up by the DB column (a `where` clause is never shadowed by the Rails 7.1+
          # has_secure_password method), scoped to the current site so a token cannot be redeemed
          # against a site that does not own the account.
          @user = current_site.users.where(password_reset_token: params[:h]).first
          if @user.nil?
            flash[:error] = t('camaleon_cms.admin.login.message.forgot_url_incorrect')
            return redirect_to cama_admin_forgot_path
          end
          # nil timestamp (or one past the window) is expired, not a NoMethodError.
          if @user.password_reset_sent_at.blank? || @user.password_reset_sent_at < 2.hours.ago
            flash[:error] = t('camaleon_cms.admin.login.message.forgot_expired')
            return redirect_to cama_admin_login_path
          end

          if params[:user].present?
            # Blank-check the *permitted* password: permit drops a non-scalar value (e.g.
            # `user[password][]=x`), and has_secure_password only validates presence on create —
            # either way `update` would be a silent no-op reported as success, consuming the token.
            # A scalar `user` param (`?user=foo`) has no .permit: treat it as an empty submission.
            reset_params = params[:user].try(:permit, :password, :password_confirmation) || {}
            if reset_params[:password].blank?
              flash[:error] = t('camaleon_cms.admin.login.message.reset_password_error')
            elsif @user.update(reset_params)
              # Single-use: clear the token so the same link cannot be replayed.
              @user.update_columns(password_reset_token: nil, password_reset_sent_at: nil) # rubocop:disable Rails/SkipsModelValidations
              flash[:notice] = t('camaleon_cms.admin.login.message.reset_password_succes')
              return redirect_to cama_admin_login_path
            else
              flash[:error] = t('camaleon_cms.admin.login.message.reset_password_error')
            end
          end
          @form_reset = true
          return render 'forgot'
        end

        # TODO: Move this out of the controller
        # send email reset password
        return if params[:user].blank?

        data_user = user_permit_data
        # Custom class finder: emails are stored downcased, so the lookup must
        # lower-case both sides regardless of DB collation.
        @user = current_site.users.find_by_email(data_user[:email]) # rubocop:disable Rails/DynamicFindBy
        if @user.present?
          send_password_reset_email(@user)
          flash[:notice] = t('camaleon_cms.admin.login.message.send_mail_succes')
          redirect_to cama_admin_login_path
          nil
        else
          flash[:error] = t('camaleon_cms.admin.login.message.send_mail_error')
          @user = current_site.users.new(data_user)
        end
      end

      def register
        @user ||= current_site.users.new
        # A scalar `user` param has no .permit — only a form-shaped submission enters this branch.
        if params[:user].respond_to?(:permit)
          params[:user][:role] = PluginRoutes.system_info['default_user_role']
          params[:user][:is_valid_email] = false if current_site.need_validate_email?
          user_data = user_permit_data
          result = cama_register_user(user_data, nil)
          if result[:result] == false && result[:type] == :captcha_error
            @user.errors.add(:captcha, result[:message])
            render 'register'
          elsif result[:result] == false && result[:type] == :stopped
            # A vetoing user_before_register handler may take over the response itself (render/redirect,
            # the user_before_login convention) or add its own errors to r[:user]; rendering again would
            # raise DoubleRenderError, so re-render only when it did not — and show a generic reason so the
            # visitor is not left with a silently re-rendered form.
            unless performed?
              if @user.errors.empty?
                @user.errors.add(:base, t('camaleon_cms.admin.users.message.registration_stopped',
                                          default: 'Registration could not be completed.'))
              end
              render 'register'
            end
          elsif result[:result]
            @user = result[:user] if result[:user].present?
            flash[:notice] = result[:message]
            send_user_confirm_email(@user) if current_site.need_validate_email?
            r = { user: @user, redirect_url: result[:redirect_url] }
            hooks_run('user_registered', r)
            # Host-check the post-registration destination for the same reason login_user host-checks its
            # explicit redirect_url: the user_registered hook is caller-controlled (downstream plugins), so
            # an off-site value falls back to the safe default unless the hook vouches for it via
            # r[:allow_external_redirect] (or its host is allowlisted).
            cama_safe_redirect(r[:redirect_url], cama_admin_login_path,
                               allow_external: r[:allow_external_redirect].present?)
          else
            render 'register'
          end
        else
          render 'register'
        end
      end

      def confirm_email
        @user = current_site.users.new
        if params[:h]
          @user = current_site.users.where(confirm_email_token: params[:h]).first
          if @user.nil?
            flash[:error] = t('camaleon_cms.admin.login.message.confirm_email_token_incorrect')
          elsif @user.confirm_email_sent_at.nil? || @user.confirm_email_sent_at < 2.hours.ago
            flash[:error] = t('camaleon_cms.admin.login.message.confirm_email_token_expired')
          else
            flash[:notice] = t('camaleon_cms.admin.login.message.confirm_email_success')
            @user.is_valid_email = true
            @user.save!
          end
        end
        redirect_to cama_admin_login_path
      end

      private

      # Hard brute-force lockout (audit finding H1): once the per-IP failed-login counter reaches the
      # limit, refuse every attempt from that IP (renders the given template with 429) for the cooldown
      # window, regardless of credentials or captcha. Re-counting the blocked attempt keeps the window
      # fresh so a persistent attacker stays locked. Returns true when it halted the action.
      def cama_halt_when_login_locked_out(template)
        return false unless cama_captcha_attack_ip_count('login') >= cama_login_lockout_limit

        cama_captcha_increment_attack('login')
        msg = t('camaleon_cms.admin.login.message.too_many_attempts',
                default: 'Too many failed attempts. Please try again later.')
        if params[:format] == 'json'
          render json: { error: msg }, status: :too_many_requests
        else
          flash.now[:error] = msg
          @user ||= current_site.users.new
          render template, status: :too_many_requests
        end
        true
      end

      # Failures past this per-IP threshold trigger the hard lockout; defaults to 4x the captcha
      # (soft) threshold and is configurable per site.
      def cama_login_lockout_limit
        soft = current_site.get_option('max_try_attack', 5).to_i
        current_site.get_option('login_lockout_attempts', soft * 4).to_i
      end

      def before_hook_session
        # NOTE: session[:cama_current_language] is for FRONTEND only (user's site language choice)
        # Admin should use admin language setting, not frontend language
        # This prevents language mixing when switching between frontend and admin contexts
        set_login_locale
        hooks_run('session_before_load')
      end

      # These pages render before authentication, so the site's languages — not a user
      # preference — pick the locale; ?locale= applies only when scalar (?locale[]=
      # would crash to_sym) and offered by the site
      def set_login_locale
        site_languages = current_site.get_languages
        requested = (params[:locale].presence&.to_sym if params[:locale].is_a?(String))
        I18n.locale = if site_languages.include?(requested)
                        requested
                      else
                        site_languages.first || I18n.default_locale
                      end
      end

      def after_hook_session
        hooks_run('session_after_load')
      end

      # verify if current permit to register users by frontend
      def verificate_register_permission
        return if current_site.get_option('permit_create_account', false)

        flash[:error] =
          t('camaleon_cms.admin.authorization_error', default: "You don't have authorization for this section.")
        redirect_to action: :login
      end

      def user_permit_data
        user_params = params.require(:user)
        # A scalar `user` param (`?user=foo`) has no .permit: treat it as an empty submission.
        return {} unless user_params.respond_to?(:permit)

        user_params.permit(:first_name, :last_name, :email, :username, :password, :password_confirmation,
                           :is_valid_email)
      end
    end
  end
end
