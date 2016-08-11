=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::SessionHelper
  # log in the user in to system
  # user: User model
  # remember_me: true/false (remember session permanently)
  def login_user(user, remember_me = false, redirect_url = nil)
    c = {value: [user.auth_token, request.user_agent, request.ip], expires: 24.hours.from_now}
    c[:domain] = :all if PluginRoutes.system_info["users_share_sites"].present? && CamaleonCms::Site.count > 1
    c[:expires] = 1.month.from_now if remember_me

    user.update({last_login_at: Time.zone.now})
    cookies[:auth_token] = c

    # user redirection
    flash[:notice] = t('camaleon_cms.admin.login.message.success', locale: current_site.get_admin_language)
    if redirect_url.present?
      redirect_to redirect_url
    elsif (return_to = cookies.delete(:return_to)).present?
      redirect_to return_to
    else
      redirect_to cama_admin_dashboard_path
    end
  end

  # login a user using username and password
  # return boolean: true => authenticated, false => authentication failed
  def login_user_with_password(username, password)
    @user = current_site.users.find_by_login(username)
    r = {user: @user, params: params, password: password, captcha_validate: true}; hooks_run('user_before_login', r)
    @user && @user.authenticate(password)
  end

  ##
  # User registration.
  #
  # user_data must contain:
  # - first_name
  # - email
  # - username
  # - password
  # - password_confirmation

  def cama_register_user(user_data, meta)
    @user = current_site.users.new(user_data)
    r = {user: @user, params: params}; hook_run('user_before_register', r)

    if current_site.security_user_register_captcha_enabled? && !cama_captcha_verified?
      {:result => false, :type => :captcha_error, :message => t('camaleon_cms.admin.users.message.error_captcha')}
    else
      if @user.save
        @user.set_metas(meta)
        message = current_site.need_validate_email? ? t('camaleon_cms.admin.users.message.created_pending_validate_email') : t('camaleon_cms.admin.users.message.created')
        r = {user: @user, message: message, redirect_url: cama_admin_login_path}; hooks_run('user_after_register', r)
        {:result => true, :message => r[:message], :redirect_url => r[:redirect_url]}
      else
        {:result => false, :type => :no_saved}
      end
    end
  end

  # check if current host is heroku
  def cama_on_heroku?
    ENV.keys.any? { |var_name| var_name.match(/(heroku|dyno)/i) }
  end

  # switch current session user into other (user)
  # after switched, this will be redirected to redirect_url or admin dashboard
  def session_switch_user(user, redirect_url = nil)
    if cama_sign_in?
      cookies[:parent_auth_token] = cookies[:auth_token]
      login_user(user, false, redirect_url)
    end
  end

  # switch current session into parent session called by session_switch_user
  # after returned into parent session, this will be redirected to redirect_url or admin dashboard
  def session_back_to_parent(redirect_url = nil)
    if cama_sign_in? && cookies[:parent_auth_token].present?
      cookies[:auth_token] = cookies[:parent_auth_token]
      redirect_to (redirect_url || cama_admin_dashboard_path), notice: "Welcome back!"
    end
  end

  # logout current user
  def cama_logout_user
    cookies.delete(:auth_token, domain: :all)
    cookies.delete(:auth_token, domain: nil)
    c_data = {value: nil, expires: 24.hours.ago}
    c_data[:domain] = :all if PluginRoutes.system_info["users_share_sites"].present? && CamaleonCms::Site.count > 1
    cookies[:auth_token] = c_data
    redirect_to params[:return_to].present? ? params[:return_to] : cama_admin_login_path, :notice => t('camaleon_cms.admin.logout.message.closed')
  end

  # check if current user is already signed
  def cama_sign_in?
    !cama_current_user.nil?
  end

  alias_method :signin?, :cama_sign_in?

  # return the role for current user
  # if not logged in, then return 'public'
  def cama_current_role
    (cama_sign_in?) ? cama_current_user.role : 'public'
  end

  # return current user logged in
  def cama_current_user
    return @cama_current_user if defined?(@cama_current_user)
    # api current user...
    @cama_current_user = cama_calc_api_current_user
    return @cama_current_user unless @cama_current_user.nil?

    return nil unless cookies[:auth_token].present?
    c = cookies[:auth_token].split("&")
    return nil unless c.size == 3

    if c[1] == request.user_agent && request.ip == c[2]
      @cama_current_user = (current_site.users_include_admins.find_by_auth_token(c[0]).decorate rescue nil)
    end
  end

  alias_method :current_user, :cama_current_user

  # check if a visitor was logged in
  # if the user was not logged in, then redirect to login url
  def cama_authenticate(redirect_uri = nil)
    params[:return_to] = redirect_uri
    unless cama_sign_in?
      flash[:error] = t('camaleon_cms.admin.login.please_login')
      cookies[:return_to] = params[:return_to].present? ? params[:return_to] : ((request.get? && params[:controller] != "admin/sessions") ? request.original_url : nil)
      redirect_to cama_admin_login_path
    end
  end

  # return the session id
  def cama_get_session_id
    session[:autor] = "Owen Peredo Diaz" unless request.session_options[:id].present?
    request.session_options[:id]
  end

  private
  # calculate the current user for API
  def cama_calc_api_current_user
    current_site.users_include_admins.find(doorkeeper_token.resource_owner_id).decorate if doorkeeper_token rescue nil
  end
end
