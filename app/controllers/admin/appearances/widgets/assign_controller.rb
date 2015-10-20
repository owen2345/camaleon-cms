=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::Appearances::Widgets::AssignController < Admin::AppearancesController
  before_action :check_permission_role
  def new
    @sidebar = current_site.sidebars.find(params[:sidebar_id])
    @widget = current_site.widgets.find(params[:widget_id])
    @assigned = @sidebar.assigned.create!({title: "Default", widget_id: @widget.id})
    render partial: "form", locals: {assigned: @assigned, widget: @widget, sidebar: @sidebar}, layout: "admin/ajax"
  end

  def update
    @sidebar = current_site.sidebars.find(params[:sidebar_id])
    @assigned = @sidebar.assigned.find(params[:id])
    if @assigned.update(params[:assign])
      @assigned.set_field_values(params[:field_options])
      flash[:notice] = t('admin.widgets.assign.updated')
    else
      flash[:error] = t('admin.widgets.assign.error_updated')
    end
    redirect_to admin_appearances_widgets_main_index_path
  end

  def destroy
    current_site.sidebars.find(params[:sidebar_id]).assigned.find(params[:id]).destroy
    render inline: ''
  end

  private
  def check_permission_role
    authorize! :manager, :widgets
  end

end
