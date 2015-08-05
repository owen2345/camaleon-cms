=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Admin::OrdersController < Plugins::Ecommerce::AdminController
  before_action :set_order, only: ['show','edit','update','destroy']

  def index
    orders = current_site.orders
    if params[:q].present?
      #orders = orders.where(params[:q].strip_stopwords2(I18n.locale).split(" ").map{|text| "posts.title LIKE '%#{text}%'" }.join(" OR "))
      orders = orders.where(slug: params[:q])
    end
    if params[:c].present?
      #orders = orders.where(user_id: User.joins(:metas).where(usermeta: {key: ['first_name','last_name']}).where("usermeta.value LIKE ?","%#{params[:c]}%").pluck(:id))
      orders = orders.joins(:details).where("plugins_order_details.customer LIKE ?","%#{params[:c]}%")
    end
    if params[:e].present?
      orders = orders.joins(:details).where("plugins_order_details.email LIKE ?","%#{params[:e]}%")
    end
    if params[:p].present?
      orders = orders.joins(:details).where("plugins_order_details.phone LIKE ?","%#{params[:p]}%")
    end
    if params[:s].present?
      orders = orders.where(status: params[:s])
    end

    @orders = orders.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end
  def show
    admin_breadcrumb_add("#{t('plugin.ecommerce.table.details')}")
    @order = @order.decorate
  end
  def new
    @order = current_site.orders.new
    render 'form'
  end
  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end
  def update
    @order.details.update(@order.details.attributes.merge(params[:order][:details]))
    @order.set_meta("billing_address", @order.meta[:billing_address].merge(params[:order][:billing_address]))
    @order.set_meta("shipping_address", @order.meta[:shipping_address].merge(params[:order][:shipping_address]))
    flash[:notice] = "#{t('plugin.ecommerce.message.order', status: "#{t('plugin.ecommerce.message.updated')}")}"
    redirect_to action: :show, id: params[:id]
  end

  # accepted order
  def accepted
    @order = current_site.orders.find_by_slug(params[:order_id])
    @order.update({status: 'accepted'})
    @order.details.update({accepted_at: Time.now})
    flash[:info] = "#{t('plugin.ecommerce.message.order', status: "#{t('plugin.ecommerce.message.accepted')}")}"
    redirect_to action: :show, id: params[:order_id]
  end
  # shipped order
  def shipped
    @order = current_site.orders.find_by_slug(params[:order_id])
    @order.update({status: 'shipped'})
    @order.details.update({shipped_at: Time.now})
    code = params[:payment][:consignment_number]
    @order.set_meta("payment", @order.meta[:payment].merge({consignment_number: code}))
    flash[:info] = "#{t('plugin.ecommerce.message.order', status: "#{t('plugin.ecommerce.message.shipped')}")}"
    redirect_to action: :show, id: params[:order_id]
  end

  private
  def set_order
    @order = current_site.orders.find_by_slug(params[:id])
  end

end
