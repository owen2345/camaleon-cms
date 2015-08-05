=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Admin::ShippingMethodsController < Plugins::Ecommerce::AdminController
  before_action :set_order, only: ['show','edit','update','destroy']

  def index
    @shipping_methods = current_site.shipping_methods.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def new
    @shipping_method = current_site.shipping_methods.new
    admin_breadcrumb_add("#{t('plugin.ecommerce.new')}")
    render 'form'
  end

  def show
    admin_breadcrumb_add("#{t('plugin.ecommerce.table.details')}")
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def create
    data = params[:plugins_ecommerce_models_shipping_method]
    @shipping_method = current_site.shipping_methods.new(data)
    if @shipping_method.save
      @shipping_method.set_meta('_default',params[:options])
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def update
    data = params[:plugins_ecommerce_models_shipping_method]
    if @shipping_method.update(data)
      @shipping_method.set_meta('_default',params[:options])
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end




  private
  def set_order
    @shipping_method = current_site.shipping_methods.find(params[:id])
  end

end
