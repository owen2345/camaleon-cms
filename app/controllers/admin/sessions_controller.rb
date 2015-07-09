class Admin::SessionsController < ApplicationController
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
    if captcha_validate && @user &&  @user.authenticate(data_user[:password])
      login_user(@user)
      captcha_reset_attack("login")
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
        sendmail(@user.email,t('admin.login.message.subject_email'),html)

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
      if captcha_verified? && @user.save
        @user.set_meta_from_form(params[:meta])
        flash[:notice] = t('admin.users.message.created')
        redirect_to admin_login_path
      else
        @first_name = params[:meta][:first_name]
        @last_name = params[:meta][:last_name]

        @user.errors[:captcha]  = t('admin.users.message.error_captcha')
        render "register"
      end
    else
      render "register"
    end

    return
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
