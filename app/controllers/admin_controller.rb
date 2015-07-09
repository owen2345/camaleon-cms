class AdminController < ApplicationController
  rescue_from CanCan::AccessDenied do |exception|
    flash[:error] = "Error: #{exception.message}"
    redirect_to admin_dashboard_path
  end
  include Admin::ApplicationHelper

  layout "admin"
  before_action :authenticate
  before_action :admin_init_actions
  before_action :admin_logged_actions
  before_action :admin_before_hooks
  after_action :admin_after_hooks

  def index

  end


  def dashboard
     render "admin/dashboard/index"
  end


  def signin

    if params[:username] == ""
      flash[:alert] = t('admin.signin.message.enter_username_password')
    elsif params[:username] != "admin"
      flash[:error] = t('admin.signin.message.combination_username_password_invalid')
    elsif params[:username] == "admin"
      flash[:notice] = t('admin.signin.message.success_user')
    end

    redirect_to action: "login"
  end

  def tinymce_assets
    render json: {
         image: {
             url: view_context.image_url(image)
         }
     }
  end

  def api
    render json: admin_api
  end

  private
  def namespace
    controller_name_segments = params[:controller].split('/')
    controller_name_segments.pop
    controller_name_segments.join('/').camelize
  end

  def current_ability
    @current_ability ||= Ability.new(current_user, current_site)
  end

  # initialize all vars and methods for admin panel
  def admin_init_actions
    I18n.locale = current_site.get_admin_language
    @_admin_menus = {}
    @_admin_breadcrumb = []
    @_extra_models_for_fields = []
    self.append_view_path(Rails.root.join("app", "apps"))
  end

  def admin_before_hooks
    hooks_run("admin_before_load")
  end

  def admin_after_hooks
    hooks_run("admin_after_load")
  end

  def admin_logged_actions
    admin_menus_add_commons unless request.xhr?
  end

end