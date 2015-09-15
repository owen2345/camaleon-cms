=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::Settings::CustomFieldsController < Admin::SettingsController
  include Admin::CustomFieldsHelper
  before_action :set_custom_field_group, only: ['show','edit','update','destroy']

  def index
    @field_groups = current_site.custom_field_groups.visible_group
    @field_groups = @field_groups.paginate(page: params[:page], per_page: current_site.admin_per_page)
  end

  def get_items
    @key = params[:key]

    render layout: false
  end

  def show
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def update
    post_data = params[:custom_field_group]
    post_data[:object_class], post_data[:objectid] = post_data[:assign_group].split(',')
    if @field_group.update(post_data)
      @field_group.add_fields(params[:fields], params[:field_options])
      @field_group.set_option('caption', post_data[:caption])
      flash[:notice] = t('admin.custom_field.message.custom_updated')
      redirect_to action: :edit, id: @field_group.id
    else
      render 'form'
    end
  end

  def new
    @field_group = current_site.custom_field_groups.new
    render 'form'
  end

  # create a new custom field group
  def create
    post_data = params[:custom_field_group]
    post_data[:object_class], post_data[:objectid] = post_data[:assign_group].split(',')
    @field_group = current_site.custom_field_groups.new(post_data)
    if @field_group.save
      @field_group.add_fields(params[:fields], params[:field_options])
      @field_group.set_option('caption', post_data[:caption])
      flash[:notice] = t('admin.custom_field.message.custom_created')
      redirect_to action: :edit, id: @field_group.id
    else
      render 'form'
    end
  end

  # destroy a custom field group
  def destroy
    @field_group.destroy

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

  def set_custom_field_group
    begin
      @field_group = current_site.custom_field_groups.find(params[:id])
    rescue
      flash[:error] = t('admin.custom_field.message.custom_group_error')
      redirect_to admin_path
    end
  end
end
