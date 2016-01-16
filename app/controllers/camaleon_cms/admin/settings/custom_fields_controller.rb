=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Settings::CustomFieldsController < CamaleonCms::Admin::SettingsController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.custom_fields"), :cama_admin_settings_custom_fields_path
  before_action :set_custom_field_group, only: [:show,:edit,:update,:destroy]
  before_action :set_post_data, only: [:create, :update]

  def index
    @field_groups = current_site.custom_field_groups.visible_group.eager_load(:site)
    @field_groups = @field_groups.where(object_class: params[:c]) if params[:c].present?
    @field_groups = @field_groups.where(objectid: params[:id]) if params[:id].present?
    @field_groups = @field_groups.paginate(page: params[:page], per_page: current_site.admin_per_page)
  end

  def get_items
    @key = params[:key]
    render partial: "get_items", layout: false
  end

  def show
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    render 'form'
  end

  def update
    if @field_group.update(@post_data)
      @field_group.add_fields(params[:fields], params[:field_options])
      @field_group.set_option('caption', @post_data[:caption])
      flash[:notice] = t('camaleon_cms.admin.custom_field.message.custom_updated')
      redirect_to action: :edit, id: @field_group.id
    else
      render 'form'
    end
  end

  def new
    add_breadcrumb I18n.t("camaleon_cms.admin.button.new")
    @field_group ||= current_site.custom_field_groups.new
    render 'form'
  end

  # create a new custom field group
  def create
    @field_group = current_site.custom_field_groups.new(@post_data)
    if @field_group.save
      @field_group.add_fields(params[:fields], params[:field_options])
      @field_group.set_option('caption', @post_data[:caption])
      flash[:notice] = t('camaleon_cms.admin.custom_field.message.custom_created')
      redirect_to action: :edit, id: @field_group.id
    else
      new
    end
  end

  # destroy a custom field group
  def destroy
    @field_group.destroy
    flash[:notice] = t('camaleon_cms.admin.custom_field.message.deleted', default: "Custom Field Group Deleted.")
    redirect_to action: :index
  end

  # reorder custom fields group
  def reorder
    params[:values].to_a.each_with_index do |value, index|
      current_site.custom_field_groups.find(value).update_column('field_order', index)
    end
    json = { size: params[:values].size }
    render json: json
  end

  private

  def set_post_data
    @post_data = params[:custom_field_group]
    @post_data[:object_class], @post_data[:objectid] = @post_data[:assign_group].split(',')
  end

  def set_custom_field_group
    begin
      @field_group = current_site.custom_field_groups.find(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.custom_field.message.custom_group_error')
      redirect_to cama_admin_path
    end
  end
end
