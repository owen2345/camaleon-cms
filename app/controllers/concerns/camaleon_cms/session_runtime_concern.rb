module CamaleonCms
  module SessionRuntimeConcern
    extend ActiveSupport::Concern

    def auth_session_error
      redirect_to cama_root_path
    end

    # Check if the current user is already signed
    def cama_sign_in?
      !cama_current_user.nil?
    end

    alias signin? cama_sign_in?

    # return the current user logged in
    def cama_current_user
      return CurrentRequest.user if CurrentRequest.user

      current_user = cama_calc_api_current_user
      return CurrentRequest.user = current_user if current_user

      return nil unless cookie_auth_token_complete?

      users = current_site.users_include_admins
      CurrentRequest.user = users.find_by(auth_token: user_auth_token_from_cookie).try(:decorate)
    end

    # log out current user
    def cama_logout_user
      cookies.delete(:auth_token, domain: :all)
      cookies.delete(:auth_token, domain: nil)
      c_data = { value: nil, expires: 24.hours.ago }
      c_data[:domain] = :all if PluginRoutes.system_info['users_share_sites'].present? && CamaleonCms::Site.count > 1
      cookies[:auth_token] = c_data
      CurrentRequest.user = nil
      redirect_to safe_redirect_url(params[:return_to]) || cama_admin_login_path,
                  notice: t('camaleon_cms.admin.logout.message.closed')
    end

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

    def login_user_with_password(username, password)
      user = current_site.users.find_by(username: username)
      r = { user: user, params: params, password: password, captcha_validate: true }
      hooks_run('user_before_login', r)
      user&.authenticate(password)
    end

    def login_user(user, remember_me = false, redirect_url = nil)
      c = { value: [user.auth_token, request.user_agent, request.ip], expires: 24.hours.from_now }
      c[:domain] = :all if PluginRoutes.system_info['users_share_sites'].present? && CamaleonCms::Site.count > 1
      c[:expires] = 1.month.from_now if remember_me

      cookies.delete(:auth_token, domain: :all)
      cookies.delete(:auth_token)

      user.update({ last_login_at: Time.zone.now })
      cookies[:auth_token] = c

      flash[:notice] = t('camaleon_cms.admin.login.message.success', locale: current_site.get_admin_language)
      return if redirect_url == false

      if redirect_url.present?
        redirect_to redirect_url
      elsif (return_to = cookies.delete(:return_to)).present?
        redirect_to safe_redirect_url(return_to) || cama_admin_dashboard_path
      else
        redirect_to cama_admin_dashboard_path
      end
    end

    def cama_register_user(user_data, meta)
      user = current_site.users.new(user_data)
      r = { user: user, params: params }
      hook_run('user_before_register', r)

      if current_site.security_user_register_captcha_enabled? && !cama_captcha_verified?
        { result: false, type: :captcha_error, message: t('camaleon_cms.admin.users.message.error_captcha') }
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

    def cama_on_heroku?
      ENV.keys.any? { |var_name| var_name.match(/(heroku|dyno)/i) }
    end

    def session_switch_user(user, redirect_url = nil)
      return unless cama_sign_in?

      session[:parent_auth_token] = cookies[:auth_token]
      login_user(user, false, redirect_url)
    end

    def session_back_to_parent(redirect_url = nil)
      return unless cama_sign_in? && session[:parent_auth_token].present?

      cookies[:auth_token] = session[:parent_auth_token]
      session.delete(:parent_auth_token)
      redirect_to (redirect_url || cama_admin_dashboard_path), notice: 'Welcome back!'
    end

    def cama_get_session_id
      session[:autor] = 'Owen Peredo Diaz' if request.session_options[:id].blank?
      id = request.session_options[:id]
      id = id.public_id if id.instance_of?(::Rack::Session::SessionId)
      id
    end

    def captcha_verify_if_under_attack(key)
      cama_captcha_under_attack?(key) ? cama_captcha_verified? : true
    end

    def cama_captcha_under_attack?(key)
      session["cama_captcha_#{key}"] ||= 0
      session["cama_captcha_#{key}"].to_i > current_site.get_option('max_try_attack', 5).to_i
    end

    def cama_captcha_verified?
      (session[:cama_captcha] || []).include?((params[:cama_captcha] || params[:captcha]).to_s.upcase)
    end

    def cama_captcha_increment_attack(key)
      session["cama_captcha_#{key}"] ||= 0
      session["cama_captcha_#{key}"] = session["cama_captcha_#{key}"].to_i + 1
    end

    def cama_captcha_reset_attack(key)
      session["cama_captcha_#{key}"] = 0
    end

    def cama_captcha_total_attacks(key)
      session["cama_captcha_#{key}"] ||= 0
    end

    def cama_captcha_tags_if_under_attack(key, captcha_parmas = [5, {}, { class: 'form-control required' }])
      cama_captcha_tag(*captcha_parmas) if cama_captcha_under_attack?(key)
    end

    def send_email(email, subject = 'Notification', content = '', from = nil, attachs = [], template_name = nil,
                   layout_name = nil, extra_data = {})
      args = { attachs: attachs, extra_data: extra_data }
      args[:template_name] = template_name if template_name.present?
      args[:layout_name] = layout_name if layout_name.present?
      args[:from] = from if from.present?
      args[:content] = content if content.present?
      cama_send_email(email, subject, args)
    end

    def cama_send_email(email_to, subject, args = {})
      args = { url_base: cama_root_url, current_site: current_site, subject: subject }.merge(args)
      args[:attachments] = args[:attachs] if args[:attachs].present?
      args[:current_site] = args[:current_site].id

      hooks_run('email', args)
      CamaleonCms::HtmlMailer.sender(email_to, args[:subject], args).deliver_later
    end

    def send_user_confirm_email(user_to_confirm)
      user_to_confirm.send_confirm_email
      confirm_email_url = cama_admin_confirm_email_url({ h: user_to_confirm.confirm_email_token })
      Rails.logger.debug "Camaleon CMS - Sending email verification to #{user_to_confirm}"
      extra_data = { url: confirm_email_url, fullname: user_to_confirm.fullname }
      send_email(user_to_confirm.email, t('camaleon_cms.admin.login.confirm.text'), '', nil, [], 'confirm_email',
                 'camaleon_cms/mailer', extra_data)
    end

    def send_password_reset_email(user_to_send)
      user_to_send.send_password_reset
      reset_url = cama_admin_forgot_url({ h: user_to_send.password_reset_token })
      extra_data = {
        url: reset_url,
        fullname: user_to_send.fullname,
        user: user_to_send
      }
      send_email(user_to_send.email, t('camaleon_cms.admin.login.message.subject_email'), '', nil, [],
                 'password_reset', 'camaleon_cms/mailer', extra_data)
    end

    def cama_send_mail_to_admin(subject, args = {})
      cama_send_email(current_site.get_option('system_email', current_site.users.admin_scope.first.email), subject,
                      args)
    end

    unless ApplicationController.method_defined?(:current_user)
      def current_user
        cama_current_user
      end
    end

    private

    def cookie_auth_token_complete?
      cookie_split_auth_token&.size == 3
    end

    def cookie_split_auth_token
      cookies[:auth_token]&.split('&')
    end

    def user_auth_token_from_cookie
      cookie_split_auth_token.first
    end

    # validate redirect url to prevent open redirect attacks
    def safe_redirect_url(url)
      return if url.blank?

      uri = URI.parse(url)
      return if uri.host.present? && uri.host != request.host

      url
    rescue URI::InvalidURIError
      nil
    end

    # calculate the current user for API
    def cama_calc_api_current_user
      begin
        doorkeeper_token
      rescue NameError
        return nil
      end
      return unless doorkeeper_token

      current_site.users_include_admins.find_by(id: doorkeeper_token.resource_owner_id).try(:decorate)
    end
  end
end
