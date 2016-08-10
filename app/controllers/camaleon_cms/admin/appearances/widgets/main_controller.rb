=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Appearances::Widgets::MainController < CamaleonCms::AdminController
  before_action :check_permission_role
  before_action :set_widgets, only: [:edit, :update, :destroy]
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.appearance")
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.widgets")

  def index
    @widgets = current_site.widgets
  end

  def new
    @widget ||= current_site.widgets.new
    render "form", layout: false
  end

  def edit
    new
  end

  def create
    params[:widget_main][:status] = "simple"
    @widget = current_site.widgets.new(params.require(:widget_main).permit!)
    if @widget.save!
      flash[:notice] = t('camaleon_cms.admin.widgets.message.created')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.message.error_created')
    end
    redirect_to action: :index
  end

  def update
    if @widget.update!(params.require(:widget_main).permit!)
      flash[:notice] = t('camaleon_cms.admin.widgets.message.updated')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.message.error_updated')
    end
    redirect_to action: :index
  end

  def destroy
    @widget = @widget.destroy!
    flash[:notice] = t('camaleon_cms.admin.widgets.message.deleted')
    redirect_to action: :index
  end

  private

  def set_widgets
    @widget = current_site.widgets.find(params[:id])
  end

  def check_permission_role
    authorize! :manage, :widgets
  end
end
