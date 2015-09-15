=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::PostTagsController < AdminController
  before_action :set_post_type
  before_action :set_post_tag, only: ['show','edit','update','destroy']

  def index
    @post_tags = @post_type.post_tags

    @post_tags = @post_tags.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def show
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
  end

  def update
    if @post_tag.update(params[:post_tag])
      @post_tag.set_options_from_form(params[:meta]) if params[:meta].present?
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'edit'
    end
  end

  def create
    data_term = params[:post_tag]
    @post_tag = @post_type.post_tags.new(data_term)
    if @post_tag.save
      @post_tag.set_options_from_form(params[:meta]) if params[:meta].present?
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'edit'
    end
  end

  def destroy
    flash[:notice] = t('admin.post_type.message.deleted') if @post_tag.destroy

    redirect_to action: :index
  end

  def list
    @post_tags = @post_type.post_tags.pluck("name")
    render json: @post_tags
  end

  private

  def set_post_type
    @post_type = current_site.post_types.find_by_id(params[:post_type_id])
    authorize! :post_tags, @post_type
  end

  def set_post_tag
    begin
      @post_tag = @post_type.post_tags.find_by_id(params[:id])
    rescue
      flash[:error] = t('admin.post_type.message.error')
      redirect_to admin_path
    end
  end
end
