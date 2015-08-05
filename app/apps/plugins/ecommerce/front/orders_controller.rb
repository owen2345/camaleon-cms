=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Front::OrdersController < Plugins::Ecommerce::FrontController


  def index
    @orders = current_site.orders.set_user(current_user).all
  end

  def show
    @order = current_site.orders.find_by_slug(params[:order]).decorate
  end

  def res_coupon
    coupon = current_site.coupons.find_by_slug(params[:code].to_s.parameterize)
    error = false
    if coupon.nil?
      error = 'Not Found Coupon'
    elsif "#{coupon.options[:expirate_date]} 23:59:59".to_datetime.to_i < Time.now.to_i
      error = 'Coupon Expired'
    elsif coupon.status != '1'
      error = 'Coupon not active'
    end
    if error
      render json: {error: error}
    else
      coupon = coupon.decorate
      render json: { data: {text: "#{coupon.the_amount}", options: coupon.options, code: coupon.slug} }
    end
  end

  def select_payment
    @order = current_site.orders.find_by_slug(params[:order])
    if params[:cancel].present?
      @order.update({status: 'canceled'})
      @order.details.update({closed_at: Time.now})
      flash[:notice] = "Canceled Order"
      redirect_to action: :index
    end

  end

  def set_select_payment
    @order = current_site.orders.find_by_slug(params[:order])
    @order.set_meta("payment",@order.meta[:payment].merge(params[:payment]))
    redirect_to plugins_ecommerce_order_pay_path(order: @order.slug)
  end

  def pay
    @order = current_site.orders.find_by_slug(params[:order])
    if @order.meta[:payment][:type] == 'paypal'
      pay_by_paypal
    elsif @order.meta[:payment][:type] == 'credit_card'
      @payment_methods = current_site.payment_methods.find(@order.meta[:payment][:payment_id])
      render 'pay_by_credit_card'
    else
      @payment_methods = current_site.payment_methods.find(@order.meta[:payment][:payment_id])
      render 'pay_by_bank_transfer'
    end
  end

  def pay_by_bank_transfer
    @order = current_site.orders.find_by_slug(params[:order])
    @order.update({status: 'received'})
    @order.details.update({received_at: Time.now})
    @order.set_meta("pay_bank_transfer", params[:details])
    flash[:notice] = "Updated Pay"
    redirect_to action: :index
  end

  def pay_by_credit_card
    @order = current_site.orders.find_by_slug(params[:order])
    res = pay_by_credit_card_run
    if res[:error].present?
      @error = res[:error]
      @payment_methods = current_site.payment_methods.find(@order.meta[:payment][:payment_id])
      render 'pay_by_credit_card'
    else
      @order.update({status: 'received'})
      @order.details.update({received_at: Time.now})
      @order.set_meta("pay_credit_card", params)
      flash[:notice] = "Updated Pay"
      redirect_to action: :index
    end
   end

  def success
    @order = current_site.orders.find_by_slug(params[:order])
    @order.update({status: 'received'})
    @order.details.update({received_at: Time.now})
    @order.set_meta("pay_paypal", {token: params[:token], PayerID: params[:PayerID]})
    flash[:notice] = "Updated Pay"
    redirect_to action: :index
  end
  def cancel
    #@order = current_site.orders.find_by_slug(params[:order])
    flash[:notice] = "Cancel Pay by Paypal"
    redirect_to action: :index
  end

  private




  def pay_by_credit_card_run
    payment = @order.meta[:payment]
    billing_address = @order.meta[:billing_address]
    details = @order.meta[:details]
    @payment_method = current_site.payment_methods.find(payment[:payment_id])

    @params = {
        :order_id => @order.slug,
        :currency => current_site.currency_code,
        :email => details[:email],
        :billing_address => { :name => "#{billing_address[:first_name]} #{billing_address[:last_name]}",
                              :address1 => billing_address[:address1],
                              :address2 => billing_address[:address2],
                              :city => billing_address[:city],
                              :state => billing_address[:state],
                              :country => billing_address[:country],
                              :zip => billing_address[:zip]
        } ,
        :description => 'Buy Products',
        :ip => request.remote_ip
    }

    @params_test = {
        ip: '54.88.208.145',
        billing_address: {
            name:      "Flaying Cakes",
            address1:  "123 5th Av.",
            city:      "Ashburn",
            state:     "LIS",
            country:   "US",
            zip:       "20147"
        }
    }

    @amount = to_cents(payment[:amount].to_f)

    paypal_options = {
        :login => @payment_method.options[:cc_paypal_login],
        :password => @payment_method.options[:cc_paypal_password],
        :signature => @payment_method.options[:cc_paypal_signature]
    }

    ActiveMerchant::Billing::Base.mode = @payment_method.options[:cc_paypal_sandbox].to_s.to_bool ? :test : :production
    @gateway = ActiveMerchant::Billing::PaypalGateway.new(paypal_options)

    @credit_card = ActiveMerchant::Billing::CreditCard.new(
        :first_name         => params[:firstName],
        :last_name          => params[:lastName],
        :number             => params[:cardNumber],
        :month              => params[:expMonth],
        :year               => "20#{params[:expYear]}",
        :verification_value => params[:cvCode])

    if @credit_card.validate.empty?
      puts "--#{@params.inspect}--"
      response = @gateway.verify(@credit_card, @params)
      #response = @gateway.purchase(@amount, @credit_card, @params)
      if response.success?
         return {success: 'Paid Correct'} #puts "Successfully charged $#{sprintf("%.2f", @amount / 100)} to the credit card #{@credit_card.display_number}"
      else
        return {error: response.message} #raise StandardError, response.message
      end
    else
      return {error: "Credit Card Invalid"}
    end
  end



  def pay_by_paypal
    payment = @order.meta[:payment]
    billing_address = @order.meta[:billing_address]
    details = @order.meta[:details]
    @payment_method = current_site.payment_methods.find(payment[:payment_id])

    ActiveMerchant::Billing::Base.mode = @payment_method.options[:paypal_sandbox].to_s.to_bool ? :test : :production
    paypal_options = {
        :login => @payment_method.options[:paypal_login],
        :password => @payment_method.options[:paypal_password],
        :signature => @payment_method.options[:paypal_signature]
    }

    @gateway = ActiveMerchant::Billing::PaypalExpressGateway.new(paypal_options)

    #subtotal, shipping, total, tax = get_totals(payment)
    @options = {
        brand_name: current_site.name,

        #allow_guest_checkout: true,
        #items: get_items(@order.meta[:products]),

        items: [{number: @order.slug, name: 'Buy Products', amount: to_cents(payment[:amount].to_f)}],
        :order_id => @order.slug,
        :currency => current_site.currency_code,
        :email => details[:email],
        :billing_address => { :name => "#{billing_address[:first_name]} #{billing_address[:last_name]}",
                              :address1 => billing_address[:address1],
                              :address2 => billing_address[:address2],
                              :city => billing_address[:city],
                              :state => billing_address[:state],
                              :country => billing_address[:country],
                              :zip => billing_address[:zip]
        } ,
        :description => 'Buy Products',
        :ip => request.remote_ip,
        :return_url => plugins_ecommerce_order_success_url(order: @order.slug),
        :cancel_return_url => plugins_ecommerce_order_cancel_url(order: @order.slug)
    }

    #response = @gateway.setup_purchase(to_cents(payment[:amount].to_f), @options)
    response = @gateway.setup_purchase(to_cents(payment[:amount].to_f), @options)

    redirect_to @gateway.redirect_url_for(response.token)
  end


  def get_items(products)
    products.collect do |key, product|
      {
          :name => product[:product_title],
          :number => product[:product_id],
          :quantity => product[:qty],
          :amount => to_cents(product[:price].to_f),
      }
    end
  end

  def get_totals(payment)
    tax = payment[:tax_total].to_f
    subtotal = payment[:sub_total].to_f
    shipping = payment[:weight_price].to_f + payment[:sub_total].to_f
    total = subtotal + shipping
    return subtotal, shipping, total, tax
  end

  def to_cents(money)
    (money*100).round
  end

end
