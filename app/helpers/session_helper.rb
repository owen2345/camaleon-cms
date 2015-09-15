=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module SessionHelper
  # log in the user in to system
  # user: User model
  # remember_me: true/false (remember session permanently)
  def login_user(user, remember_me = false, redirect_url = nil)
    c = {value: [user.auth_token, request.user_agent, request.ip], expires: 24.hours.from_now }
    # c[:domain] = :all if PluginRoutes.system_info["users_share_sites"].present? && Site.main_site.get_meta("share_sessions", true) && !cookies[:login].present?
    c[:domain] = :all if PluginRoutes.system_info["users_share_sites"].present? && Site.count > 1
    c[:expires] = 1.month.from_now if remember_me

    Site.main_site.set_meta("share_sessions", false) if cookies.delete(:login).present?
    user.update({last_login_at: Time.zone.now})

    cookies[:auth_token] = c
    cookies[:login] = true

    # user redirection
    flash[:notice] = t('admin.login.message.success', locale: current_site.get_admin_language)
    if redirect_url.present?
      redirect_to redirect_url
    elsif (return_to = cookies.delete(:return_to)).present?
      redirect_to return_to
    else
      redirect_to admin_dashboard_path
    end
  end

  # check if current host is heroku
  def on_heroku?
    ENV.keys.any? {|var_name| var_name.match(/(heroku|dyno)/i) }
  end

  # switch current session user into other (user)
  # after switched, this will be redirected to redirect_url or admin dashboard
  def session_switch_user(user, redirect_url = nil)
    if signin?
      cookies[:parent_auth_token] = cookies[:auth_token]
      login_user(user, false, redirect_url)
    end
  end

  # switch current session into parent session called by session_switch_user
  # after returned into parent session, this will be redirected to redirect_url or admin dashboard
  def session_back_to_parent(redirect_url = nil)
    if signin? && cookies[:parent_auth_token].present?
      cookies[:auth_token] = cookies[:parent_auth_token]
      redirect_to (redirect_url||admin_dashboard_path), notice: "Welcome back!"
    end
  end

  # logout current user
  def logout_user
    cookies.delete(:auth_token, domain: :all)
    cookies.delete(:auth_token, domain: nil)
    cookies[:auth_token] = {value: nil, expires: 24.hours.ago, domain: (PluginRoutes.system_info["users_share_sites"] && Site.count > 1 ? :all : nil)}
    cookies.delete :login
    redirect_to params[:return_to].present? ? params[:return_to] : admin_login_path, :notice => t('admin.logout.message.closed')
  end

  # check if current user is already signed
  def signin?
    !current_user.nil?
  end

  # return the role for current user
  # if not logged in, then return 'public'
  def current_role
    (signin?)? current_user.role : 'public'
  end

  # return current user logged in
  def current_user
    return @current_user if defined?(@current_user)
    return nil unless cookies[:auth_token].present?
    c = cookies[:auth_token].split("&")
    return nil unless c.size == 3

    if c[1] == request.user_agent && request.ip == c[2]
      @current_user = (current_site.users_include_admins.find_by_auth_token(c[0]).decorate rescue nil)
    end
  end

  # check if a visitor was logged in
  # if the user was not logged in, then redirect to login url
  def authenticate(redirect_uri = nil)
    params[:return_to] = redirect_uri
    unless signin?
      flash[:error] = "Required Login"
      cookies[:return_to] = params[:return_to].present? ? params[:return_to] : ((request.get? && params[:controller] != "admin/sessions") ? request.original_url : nil)
      redirect_to admin_login_path
    end
  end

  # return the session id
  def get_session_id
    session[:autor] = "Owen Peredo Diaz" unless request.session_options[:id].present?
    request.session_options[:id]
  end
end
