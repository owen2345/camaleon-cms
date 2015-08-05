=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Admin::PaymentMethodsController < Plugins::Ecommerce::AdminController
  before_action :set_order, only: ['show','edit','update','destroy']

  def index
    @payment_methods = current_site.payment_methods.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def new
    @payment_method = current_site.payment_methods.new
    admin_breadcrumb_add("#{t('plugin.ecommerce.new')}")
    render 'form'
  end

  def show
    admin_breadcrumb_add("#{t('plugin.ecommerce.table.details')}")
    @payment_method = @payment_method.decorate
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def create
    data = params[:plugins_ecommerce_models_payment_method]
    @payment_method = current_site.payment_methods.new(data)
    if @payment_method.save
      @payment_method.set_meta('_default',params[:options])
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def update
    data = params[:plugins_ecommerce_models_payment_method]

    if defined?(params[:options][:type]) && params[:options][:type] == 'paypal'
      unless valid_paypal_data(params[:options])
        flash.now[:error] = "#{t('plugin.ecommerce.message.error_paypal_values')})}"
        render 'form'
        return
      end
    end

    if @payment_method.update(data)
      @payment_method.set_meta('_default',params[:options])
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end




  private
  def set_order
    @payment_method = current_site.payment_methods.find(params[:id])#.decorate
  end

  def valid_paypal_data(data)
    ActiveMerchant::Billing::Base.mode = data[:paypal_sandbox].to_s.to_bool ? :test : :production
    paypal_options = {
        :login => data[:paypal_login],
        :password => data[:paypal_password],
        :signature => data[:paypal_signature]
    }
    opts = {
        :ip => request.remote_ip,
        :return_url => plugins_ecommerce_order_success_url(order: 'test'),
        :cancel_return_url => plugins_ecommerce_order_cancel_url(order: 'test')
    }
    @gateway = ActiveMerchant::Billing::PaypalExpressGateway.new(paypal_options)
    response = @gateway.setup_authorization(500, opts)
    response.success?
  end
end
