=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::Settings::SitesController < Admin::SettingsController
  before_action :set_site, only: ['show','edit','update','destroy']
  before_action :check_shared_status
  def index
    @sites = Site.all.order(:term_group)
    @sites = @sites.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
    r = { sites: @sites, render: "index" }
    hooks_run("list_site", r)
    render r[:render]
  end

  def show
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def update
    if @site.update(params[:site])
      save_metas(@site)
      flash[:notice] = t('admin.sites.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def new
    @site = Site.new.decorate
    render 'form'
  end

  def create
    site_data = params[:site]
    @site = Site.new(site_data)
    if @site.save
      save_metas(@site)
      site_after_install(@site, @site.get_theme_slug)
      flash[:notice] = t('admin.sites.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def destroy
    flash[:notice] = t('admin.sites.message.deleted') if @site.destroy
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
      @site = Site.find_by_id(params[:id]).decorate
    rescue
      flash[:error] = t('admin.sites.message.error')
      redirect_to admin_path
    end
  end

  # check if the system.config manage shared users
  def check_shared_status
    unless current_site.manage_sites?
      flash[:error] = t('admin.sites.message.unauthorized')
      redirect_to admin_path
    end
  end
end
