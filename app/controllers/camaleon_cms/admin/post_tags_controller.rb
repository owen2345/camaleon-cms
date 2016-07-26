=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::PostTagsController < CamaleonCms::AdminController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.contents")
  before_action :set_post_type
  before_action :set_post_tag, only: ['show','edit','update','destroy']

  def index
    @post_tags = @post_type.post_tags
    @post_tags = @post_tags.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  # render post tag view
  def show
  end

  # render post tag edit form
  def edit
    add_breadcrumb t("camaleon_cms.admin.button.edit")
  end

  # save changes of a post tag
  def update
    if @post_tag.update(params.require(:post_tag).permit!)
      @post_tag.set_options(params[:meta]) if params[:meta].present?
      @post_tag.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.post_type.message.updated')
      redirect_to action: :index
    else
      render edit
    end
  end

  # render post tag create form
  def create
    @post_tag = @post_type.post_tags.new(params.require(:post_tag).permit!)
    if @post_tag.save
      @post_tag.set_options(params[:meta]) if params[:meta].present?
      @post_tag.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'edit'
    end
  end

  # destroy a post tag
  def destroy
    flash[:notice] = t('camaleon_cms.admin.post_type.message.deleted') if @post_tag.destroy
    redirect_to action: :index
  end

  # render a json of post tags of a post type
  def list
    @post_tags = @post_type.post_tags.pluck("name")
    render json: @post_tags
  end

  private

  def set_post_type
    @post_type = current_site.post_types.find_by_id(params[:post_type_id]).decorate
    authorize! :post_tags, @post_type
    add_breadcrumb @post_type.the_title, @post_type.the_admin_url
    add_breadcrumb t("camaleon_cms.admin.post_type.post_tags"), url_for({action: :index})
  end

  def set_post_tag
    begin
      @post_tag = @post_type.post_tags.find_by_id(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.post_type.message.error')
      redirect_to cama_admin_path
    end
  end
end
