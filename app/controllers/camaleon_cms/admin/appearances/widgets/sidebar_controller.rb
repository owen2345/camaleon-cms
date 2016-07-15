=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Appearances::Widgets::SidebarController < CamaleonCms::AdminController
  before_action :check_permission_role
  before_action :set_sidebar, only: [:edit, :update, :destroy]

  def new
    @sidebar ||= current_site.sidebars.new
    render 'form', layout: false
  end

  def create
    @sidebar = current_site.sidebars.new(params.require(:widget_sidebar).permit!)
    if @sidebar.save
      flash[:notice] = t('camaleon_cms.admin.widgets.sidebar.created')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.sidebar.error_created')
    end
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  def edit
    new
  end

  def update
    if @sidebar.update(params.require(:widget_sidebar).permit!)
      flash[:notice] = t('camaleon_cms.admin.widgets.sidebar.updated')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.sidebar.error_updated')
    end
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  def reorder
    params[:pos].each_with_index do |assigned_id, index|
      current_site.sidebars.find(params[:sidebar_id]).assigned.find(assigned_id).update(item_order: index) if assigned_id.present?
    end
    render inline: ""
  end

  def destroy
    @sidebar = @sidebar.destroy
    flash[:notice] = t('camaleon_cms.admin.widgets.sidebar.error_deleted')
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  private

  def set_sidebar
    @sidebar = current_site.sidebars.find(params[:id])
  end

  def check_permission_role
    authorize! :manage, :widgets
  end

end
