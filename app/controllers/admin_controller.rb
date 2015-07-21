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

  private
  # initialize all vars and methods for admin panel
  def admin_init_actions
    I18n.locale = current_site.get_admin_language
    @_admin_menus = {}
    @_admin_breadcrumb = []
    @_extra_models_for_fields = []
    self.append_view_path(Rails.root.join("app", "apps"))
  end

  # trigger hooks for admin panel before admin load
  def admin_before_hooks
    hooks_run("admin_before_load")
  end

  # trigger hooks for admin panel after admin load
  def admin_after_hooks
    hooks_run("admin_after_load")
  end

  def admin_logged_actions
    admin_menus_add_commons unless request.xhr?
  end

end