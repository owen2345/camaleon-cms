=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::SessionsController < CamaleonCms::CamaleonController
  skip_before_filter :cama_authenticate
  before_action :before_hook_session
  after_action :after_hook_session
  before_action :verificate_register_permission, only: [:register]
  layout 'camaleon_cms/login'

  # you can pass return_to as a param (mysite.com/admin/login?return_to=my-url) and this will be used after user logged in
  def login
    if signin?
      redirect_to (params[:return_to].present? ? params[:return_to] : admin_dashboard_path)
    else
      @user ||= current_site.users.new
    end
    render "login"
  end

  def login_post
    data_user = params[:user]
    cipher = Gibberish::AES::CBC.new(cama_get_session_id)
    data_user[:password] = cipher.decrypt(data_user[:password]) rescue nil
    @user = current_site.users.find_by_username(data_user[:username])
    captcha_validate = captcha_verify_if_under_attack("login")
    r = {user: @user, params: params, password: data_user[:password], captcha_validate: captcha_validate, stop_process: false}; hooks_run("user_before_login", r)
    return if r[:stop_process] # permit to redirect for data completion
    if captcha_validate && @user && @user.authenticate(data_user[:password])
      cama_captcha_reset_attack("login")
      r={user: @user, redirect_to: nil }; hooks_run('after_login', r)
      login_user(@user, params[:remember_me].present?, r[:redirect_to])
    else
      cama_captcha_increment_attack("login")
      if captcha_validate
        flash[:error] = t('camaleon_cms.admin.login.message.fail')
      else
        flash[:error] = t('camaleon_cms.admin.login.message.invalid_caption')
      end
      @user = current_site.users.new(data_user)
      login
    end
  end

  def logout
    cama_logout_user
  end


  def forgot
    @user = current_site.users.new
    # get form reset password
    if params[:h]
      @user = current_site.users.where(password_reset_token: params[:h]).first
      if @user.nil?
        flash[:error] = t('camaleon_cms.admin.login.message.forgot_url_incorrect')
        redirect_to cama_forgot_path
        return
      elsif @user.password_reset_sent_at < 2.hours.ago
        flash[:error] = t('camaleon_cms.admin.login.message.forgot_expired')
        redirect_to cama_admin_login_path
      else
        # saved new password
        if params[:user].present?
          if @user.update(params[:user].permit(:password, :password_confirmation))
            flash[:notice] = t('camaleon_cms.admin.login.message.reset_password_succes')
            redirect_to admin_login_path
            return
          else
            flash[:error] = t('camaleon_cms.admin.login.message.reset_password_error')
          end
        end
        @form_reset = true
        render "forgot"
        return
      end
    end

    # TODO: Move this out of the controller
    # send email reset password
    if params[:user].present?
      data_user = params[:user]
      @user = current_site.users.find_by_email(data_user[:email])
      if @user.present?
        @user.send_password_reset

        reset_url = cama_admin_forgot_url({h: @user.password_reset_token})

        html = "<p>#{t('camaleon_cms.admin.login.message.hello')}, <b>#{@user.fullname}</b></p>
            <p>#{t('camaleon_cms.admin.login.message.reset_url')}:</p>
            <p><a href='#{reset_url}'><b>#{reset_url}</b></a></p> "
        sendmail(@user.email, t('camaleon_cms.admin.login.message.subject_email'), html)

        flash[:notice] = t('camaleon_cms.admin.login.message.send_mail_succes')
        redirect_to cama_admin_login_path
        return
      else
        flash[:error] = t('camaleon_cms.admin.login.message.send_mail_error')
        @user = current_site.users.new(data_user)
      end
    end
  end

  def register
    @user ||= current_site.users.new
    if params[:user].present?
      params[:user][:role] = PluginRoutes.system_info["default_user_role"]
      user_data = params[:user]
      @user = current_site.users.new(user_data)
      r = {user: @user, params: params}; hooks_run('user_before_register', r)

      if current_site.security_user_register_captcha_enabled? && !cama_captcha_verified?
        @first_name = params[:meta][:first_name]
        @last_name = params[:meta][:last_name]

        @user.errors[:captcha] = t('camaleon_cms.admin.users.message.error_captcha')
        render 'register'
      else
        if @user.save
          @user.set_meta_from_form(params[:meta])
          r = {user: @user, message: t('camaleon_cms.admin.users.message.created'), redirect_url: cama_admin_login_path}; hooks_run('user_after_register', r)
          flash[:notice] = r[:message]
          r={user: @user}; hooks_run('user_registered', r)
          redirect_to r[:redirect_url]
        else
          @first_name = params[:meta][:first_name]
          @last_name = params[:meta][:last_name]
          render 'register'
        end
      end
    else
      render 'register'
    end
  end

  private

  def before_hook_session
    I18n.locale = params[:locale] || current_site.get_languages.first
    hooks_run("session_before_load")
  end

  def after_hook_session
    hooks_run("session_after_load")
  end

  # verify if current permit to register users by frontend
  def verificate_register_permission
    unless current_site.get_option('permit_create_account', false)
      flash[:error] = t('camaleon_cms.admin.authorization_error', default: "You don't have authorization for this section.")
      return redirect_to action: :login
    end
  end

end
