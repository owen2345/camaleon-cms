=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class AdminController < CamaleonController
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

  # render admin dashabord
  def index
  end

  # render admin dashboard
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
    # self.append_view_path(Rails.root.join("app", "apps"))
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
