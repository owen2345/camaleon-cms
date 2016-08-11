=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::SessionsController < CamaleonCms::CamaleonController
  skip_before_action :cama_authenticate, raise: false
  before_action :before_hook_session
  after_action :after_hook_session
  before_action :verificate_register_permission, only: [:register]
  layout 'camaleon_cms/login'

  # you can pass return_to as a param (mysite.com/admin/login?return_to=my-url) and this will be used after user logged in
  def login
    if signin?
      return redirect_to (params[:return_to].present? ? params[:return_to] : cama_admin_dashboard_path)
    else
      cookies[:return_to] = params[:return_to] if params[:return_to].present?
      @user ||= current_site.users.new
    end
    render "login"
  end

  def login_post
    data_user = params[:user]
    cipher = Gibberish::AES::CBC.new(cama_get_session_id)
    data_user[:password] = cipher.decrypt(data_user[:password]) rescue nil
    @user = current_site.users.find_by_login(data_user[:username])
    captcha_validate = captcha_verify_if_under_attack("login")
    r = {user: @user, params: params, password: data_user[:password], captcha_validate: captcha_validate, stop_process: false}; hooks_run("user_before_login", r)
    return if r[:stop_process] # permit to redirect for data completion
    if captcha_validate && @user && @user.authenticate(data_user[:password])
      #Email validation if is necessary
      if @user.is_valid_email? || !current_site.need_validate_email?
        cama_captcha_reset_attack("login")
        r={user: @user, redirect_to: nil}; hooks_run('after_login', r)
        login_user(@user, params[:remember_me].present?, r[:redirect_to])
      else
        flash[:error] = t('camaleon_cms.admin.login.message.email_not_validated')
        @user = current_site.users.new(data_user)
        login
      end
    else
      cama_captcha_increment_attack("login")
      if captcha_validate
        flash[:error] = t('camaleon_cms.admin.login.message.fail')
      else
        flash[:error] = t('camaleon_cms.admin.login.message.invalid_caption')
      end
      @user = current_site.users.new(data_user.permit!)
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
            redirect_to cama_admin_login_path
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
        send_password_reset_email(@user)
        flash[:notice] = t('camaleon_cms.admin.login.message.send_mail_succes')
        redirect_to cama_admin_login_path
        return
      else
        flash[:error] = t('camaleon_cms.admin.login.message.send_mail_error')
        @user = current_site.users.new(data_user.permit!)
      end
    end
  end

  def register
    @user ||= current_site.users.new
    if params[:user].present?
      params[:user][:role] = PluginRoutes.system_info["default_user_role"]
      params[:user][:is_valid_email] = false if current_site.need_validate_email?
      user_data = params.require(:user).permit!
      result = cama_register_user(user_data, params[:meta])
      if result[:result] == false && result[:type] == :captcha_error
        @user.errors[:captcha] = t('camaleon_cms.admin.users.message.error_captcha')
        render 'register'
      elsif result[:result]
        flash[:notice] = result[:message]
        send_user_confirm_email(@user) if current_site.need_validate_email?
        r = {user: @user, redirect_url: result[:redirect_url]}; hooks_run('user_registered', r)
        redirect_to r[:redirect_url]
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

  def before_hook_session
    session[:cama_current_language] = params[:cama_set_language].to_sym if params[:cama_set_language].present?
    I18n.locale = params[:locale] || session[:cama_current_language] || current_site.get_languages.first
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
