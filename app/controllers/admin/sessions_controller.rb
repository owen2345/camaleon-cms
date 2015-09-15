=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::SessionsController < CamaleonController
  skip_before_filter :authenticate
  before_action :before_hook_session
  after_action :after_hook_session
  layout 'login'

  # you can pass return_to as a param (mysite.com/admin/login?return_to=my-url) and this will be used after user logged in
  def login
    if signin?
      redirect_to (params[:return_to].present? ? params[:return_to] : admin_dashboard_path)
    else
      @user = current_site.users.new
    end
  end

  def login_post
    data_user = params[:user]
    cipher = Gibberish::AES::CBC.new(get_session_id)
    data_user[:password] = cipher.decrypt(data_user[:password]) rescue nil
    @user = current_site.users.find_by_username(data_user[:username])
    captcha_validate = captcha_verify_if_under_attack("login")
    r = {user: @user, params: params, password: data_user[:password], captcha_validate: captcha_validate}; hooks_run("user_before_login", r)
    if captcha_validate && @user &&  @user.authenticate(data_user[:password])
      captcha_reset_attack("login")
      login_user(@user)
    else
      captcha_increment_attack("login")
      if captcha_validate
        flash[:error] =  t('admin.login.message.fail')
      else
        flash[:error] =  "Invalid captcha"
      end
      @user = current_site.users.new(data_user)
      render 'admin/sessions/login'
    end
  end

  def logout
    logout_user
  end


  def forgot
    @user = current_site.users.new

    # get form reset password
    if params[:h]
      @user = current_site.users.where(password_reset_token: params[:h]).first
      if @user.nil?
        flash[:error] = t('admin.login.message.forgot_url_incorrect')
        redirect_to forgot_path
        return
      elsif @user.password_reset_sent_at < 2.hours.ago
        flash[:error] = t('admin.login.message.forgot_expired')
        redirect_to admin_login_path
      else
        # saved new password
        if params[:user].present?
          if @user.update(params[:user].permit(:password, :password_confirmation))
            flash[:notice] = t('admin.login.message.reset_password_succes')
            redirect_to admin_login_path
            return
          else
            flash[:error] = t('admin.login.message.reset_password_error')
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

        reset_url = admin_forgot_url({h: @user.password_reset_token})

        html = "<p>#{t('admin.login.message.hello')}, <b>#{@user.fullname}</b></p>
            <p>#{t('admin.login.message.reset_url')}:</p>
            <p><a href='#{reset_url}'><b>#{reset_url}</b></a></p> "
        sendmail(@user.email,t('admin.login.message.subject_email'), html)

        flash[:notice] = t('admin.login.message.send_mail_succes')
        redirect_to admin_login_path
        return
      else
        flash[:error] = t('admin.login.message.send_mail_error')
        @user = current_site.users.new(data_user)
      end
    end
  end

  def register
    @user ||= current_site.users.new

    if params[:user].present?
      params[:user][:role] = "client"

      user_data = params[:user]

      @user = current_site.users.new(user_data)
      r = {user: @user, params: params}; hooks_run("user_before_register", r)
      if captcha_verified? && @user.save
        @user.set_meta_from_form(params[:meta])
        r = {user: @user, message: t('admin.users.message.created'), redirect_url: admin_login_path}; hooks_run("user_after_register", r)
        flash[:notice] = r[:message]
        redirect_to r[:redirect_url]
      else
        @first_name = params[:meta][:first_name]
        @last_name = params[:meta][:last_name]

        @user.errors[:captcha]  = t('admin.users.message.error_captcha')
        render "register"
      end
    else
      render "register"
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
end
