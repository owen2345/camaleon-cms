=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Front::CheckoutController < Plugins::Ecommerce::FrontController

  before_action :set_cart

  def index
    if @cart.products.size > 0
      @products = @cart.products
    else
      flash[:notice] = "Not found products."
      redirect_to action: :cart_index
    end
  end

  def processing


    @products = @cart.products

    total_weight = 0
    tax_total = 0
    sub_total = 0

    pay_status = 'unpaid'

    @products.each do |product|
      product = product.decorate
      product_options = @cart.get_option("product_#{product.id}")
      price = product_options[:price].to_f
      qty = product_options[:qty].to_f
      qty_real = product.get_field_value('ecommerce_qty').to_f
      if qty_real < 1
        @cart.delete_option("product_#{product.id}") if qty < 1
      else
        qty = qty_real if qty > qty_real
        tax_product = product_options[:tax].to_f
        tax_total += tax_product * qty
        total_weight += product_options[:weight].to_f * product_options[:qty].to_f
        sub_total += price * qty
        product.update_field_value('ecommerce_qty', (qty_real - qty).to_i)
      end
    end

    shipping_method = current_site.shipping_methods.find(params[:order][:payment][:shipping_method])
    weight_price = shipping_method.get_price_from_weight(total_weight)

    total = sub_total + tax_total + weight_price

    payment_amount = total

    coupon_total = ''
    coupon_amount = 0
    if params[:order][:payment][:coupon_code].present?
      coupon = current_site.coupons.find_valid_by_code(params[:order][:payment][:coupon_code])
      if coupon.present?
        coupon = coupon.decorate
        coupon_total = coupon.the_amount
        opts = coupon.options

        case opts[:discount_type]
          when 'free_ship'
            pay_status = 'received'
            coupon_amount = payment_amount
          when 'percent'
            coupon_amount = payment_amount * opts[:amount].to_f / 100
          when 'money'
            coupon_amount = opts[:amount].to_f
        end
        payment_amount = payment_amount - coupon_amount
      end
    end

    payment_amount = 0 if payment_amount < 0

    order_id = Time.now.to_i
    @order = current_site.orders.set_user(current_user).create(name: "Order #{order_id}", slug: order_id, status: pay_status )
    details = params[:order][:details]
    details[:received_at] = Time.now
    @order.create_details(details)
    @order.set_meta("products", @cart.options)
    @order.set_meta("details", params[:order][:details])
    @order.set_meta("billing_address", params[:order][:billing_address])
    @order.set_meta("shipping_address", params[:order][:shipping_address])
    total = sub_total + tax_total + weight_price
    @order.set_meta("payment", params[:order][:payment].merge({
                                                     amount: payment_amount,
                                                     currency_code: current_site.currency_code,
                                                     total: total,
                                                     sub_total: sub_total,
                                                     tax_total: tax_total,
                                                     weight_price: weight_price,
                                                     coupon: coupon_total,
                                                     coupon_amount: coupon_amount
                                                 }))

    @cart.destroy

    if payment_amount > 0
      redirect_to plugins_ecommerce_order_select_payment_path(order: @order.slug)
    else
      flash[:notice] = "Saved Orders."
      redirect_to plugins_ecommerce_orders_path
    end
  end

  def cart_index
    @products = @cart.products
  end

  # params[cart]: product_id,  qty
  def cart_add
    data = params[:cart]
    product_id = data[:product_id]
    @cart.add_product(product_id)
    @cart.set_option("product_#{product_id}", e_add_data_product(data, product_id))
    flash[:notice] = "Add correct product in Cart."
    redirect_to action: :cart_index
  end

  def cart_update
    params[:products].each do |data|
      product_id = data[:product_id]
      @cart.set_option("product_#{product_id}", e_add_data_product(data, product_id))
    end
    flash[:notice] = "Updated product in Cart."
    redirect_to action: :cart_index
  end

  def cart_remove
    @cart.remove_product(params[:product_id])
    @cart.delete_option("product_#{params[:product_id]}")
    flash[:notice] = "Deleted correct product in Cart."
    redirect_to action: :cart_index
  end

  def orders
    render json: current_site.orders.set_user(current_user)
  end

  private
  def set_cart
    @cart = current_site.carts.set_user(current_user).first_or_create(name: "Cart by #{current_user.id}")
  end



  def process_pay(data = {})


  end


end
