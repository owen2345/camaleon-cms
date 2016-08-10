=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Settings::SitesController < CamaleonCms::Admin::SettingsController
  before_action :set_site, only: [:show, :edit, :update, :destroy]
  before_action :check_shared_status
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.sites"), :cama_admin_settings_sites_path

  def index
    @sites = CamaleonCms::Site.all.order(:term_group)
    @sites = @sites.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
    r = { sites: @sites, render: "index" }
    hooks_run("list_site", r)
    render r[:render]
  end

  def show
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    render 'form'
  end

  def update
    tmp = @site.slug
    if @site.update(params.require(:site).permit!)
      save_metas(@site)
      flash[:notice] = t('camaleon_cms.admin.sites.message.updated')
      if @site.id == Cama::Site.main_site.id && tmp != @site.slug
        redirect_to @site.the_admin_url
      else
        redirect_to action: :index
      end
    else
      edit
    end
  end

  def new
    add_breadcrumb I18n.t("camaleon_cms.admin.button.new")
    @site ||= CamaleonCms::Site.new.decorate
    render 'form'
  end

  def create
    site_data = params.require(:site).permit!
    @site = CamaleonCms::Site.new(site_data)
    if @site.save
      save_metas(@site)
      site_after_install(@site, @site.get_theme_slug)
      flash[:notice] = t('camaleon_cms.admin.sites.message.created')
      redirect_to action: :index
    else
      new
    end
  end

  def destroy
    flash[:notice] = t('camaleon_cms.admin.sites.message.deleted') if @site.destroy
    redirect_to action: :index
  end

  private

  def save_metas(site)
    if params[:metas].present?
      params[:metas].each do |meta, val|
        site.set_meta(meta, val)
      end
    end
  end

  def set_site
    begin
      @site = CamaleonCms::Site.find_by_id(params[:id]).decorate
    rescue
      flash[:error] = t('camaleon_cms.admin.sites.message.error')
      redirect_to cama_admin_path
    end
  end

  # check if the system.config manage shared users
  def check_shared_status
    unless current_site.manage_sites?
      flash[:error] = t('camaleon_cms.admin.sites.message.unauthorized')
      redirect_to cama_admin_path
    end
  end
end
