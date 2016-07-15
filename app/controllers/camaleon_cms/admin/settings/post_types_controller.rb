=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Settings::PostTypesController < CamaleonCms::Admin::SettingsController
  before_action :set_post_type, only: [:show,:edit,:update, :destroy]
  before_action :set_data_term, only: [:create, :update]
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.content_groups"), :cama_admin_settings_post_types_path

  def index
    @post_types = current_site.post_types
    @post_types = @post_types.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
    render "index"
  end

  def show
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
  end

  def update
    if @post_type.update(@data_term)
      flash[:notice] = t('camaleon_cms.admin.post_type.message.updated')
      redirect_to action: :index
    else
      edit
    end
  end

  def create
    @post_type = current_site.post_types.new(@data_term)
    if @post_type.save
      flash[:notice] = t('camaleon_cms.admin.post_type.message.created')
      redirect_to action: :index
    else
      index
    end
  end

  def destroy
    flash[:notice] = t('camaleon_cms.admin.post_type.message.deleted') if @post_type.destroy
    redirect_to action: :index
  end

  private

  def set_data_term
    data_term = params.require(:post_type).permit!
    data_term[:data_options] = params[:meta]
    @data_term = data_term
  end

  def set_post_type
    begin
      @post_type = current_site.post_types.find_by_id(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.post_type.message.error')
      redirect_to cama_admin_path
    end
  end
end
