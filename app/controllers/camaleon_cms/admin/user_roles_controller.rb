=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::UserRolesController < CamaleonCms::AdminController
  before_action :validate_role
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.users"), :cama_admin_users_url
  add_breadcrumb I18n.t("camaleon_cms.admin.users.user_roles"), :cama_admin_user_roles_path
  before_action :set_user_roles, only: ['show','edit','update','destroy']

  def index
    @user_roles = current_site.user_roles
    @user_roles = @user_roles.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def show
  end

  def new
    add_breadcrumb I18n.t("camaleon_cms.admin.button.new")
    @user_role ||= current_site.user_roles.new
    render 'form'
  end

  def create
    user_role_data = params.require(:user_role).permit!
    @user_role = current_site.user_roles.new(user_role_data)
    if @user_role.save
      @user_role.set_meta("_post_type_#{current_site.id.to_s}", defined?(params[:rol_values][:post_type]) ? params[:rol_values][:post_type] : {})
      @user_role.set_meta("_manager_#{current_site.id.to_s}", defined?(params[:rol_values][:post_type]) ? params[:rol_values][:manager] : {})
      flash[:notice] = t('camaleon_cms.admin.users.message.rol_created')
      redirect_to action: :edit, id: @user_role.id
    else
      new
    end
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    render 'form'
  end

  def update
    if @user_role.editable? && @user_role.update(params.require(:user_role).permit!)
      @user_role.set_meta("_post_type_#{current_site.id.to_s}", defined?(params[:rol_values][:post_type]) ? params[:rol_values][:post_type] : {})
      @user_role.set_meta("_manager_#{current_site.id.to_s}", defined?(params[:rol_values][:post_type]) ? params[:rol_values][:manager] : {})
      flash[:notice] = t('camaleon_cms.admin.users.message.rol_updated')
      redirect_to action: :edit, id: @user_role.id
    else
      edit
    end
  end

  def destroy
    @user_role.destroy
    flash[:notice] = t('camaleon_cms.admin.users.message.rol_deleted')
    redirect_to action: :index
  end

  private
  def validate_role
    authorize! :manage, :users
  end

  def set_user_roles
    begin
      @user_role = current_site.user_roles.find(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.users.message.rol_error')
      redirect_to action: :index
    end
  end
end
