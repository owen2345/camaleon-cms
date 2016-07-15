=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::CategoriesController < CamaleonCms::AdminController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.contents")
  before_action :set_post_type
  before_action :set_category, only: ['show','edit','update','destroy']

  def index
    @categories = @post_type.categories
    @categories = @categories.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
    hooks_run("list_category", {categories: @categories, post_type: @post_type})
  end

  def show
  end

  def edit
    add_breadcrumb t("camaleon_cms.admin.button.edit")
  end

  def update
    if @category.update(params.require(:category).permit!)
      @category.set_options(params[:meta])
      @category.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'edit'
    end
  end

  def create
    @category = @post_type.categories.new(params.require(:category).permit!)
    if @category.save
      @category.set_options(params[:meta])
      @category.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'edit'
    end
  end

  # return html category list used to reload categories list in post editor form
  def list
    render inline: post_type_html_inputs(@post_type, "categories", "categories" , "checkbox" , params[:categories] || [], "categorychecklist", true )
  end

  def destroy
    flash[:notice] = t('camaleon_cms.admin.post_type.message.deleted') if @category.destroy
    redirect_to action: :index
  end

  private
  # define parent post type
  def set_post_type
    begin
      @post_type = current_site.post_types.find_by_id(params[:post_type_id]).decorate
    rescue
      flash[:error] =  t('camaleon_cms.admin.request_error_message')
      redirect_to cama_admin_path, {error: 'Error Post Type'}
    end
    add_breadcrumb @post_type.the_title, @post_type.the_admin_url
    add_breadcrumb t("camaleon_cms.admin.table.categories"), url_for({action: :index})
    authorize! :categories, @post_type
  end

  def set_category
    begin
      @category = CamaleonCms::Category.find_by_id(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.post_type.message.error')
      redirect_to cama_admin_path
    end
  end
end
