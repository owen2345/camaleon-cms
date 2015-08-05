=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::Ecommerce::EcommerceHelper

  def ecommerce_on_render_post(d)
    if d[:post_type].slug == 'commerce'
      ecommerce_add_assets_in_front
      d[:render] = "ecommerce/views/front/product"
    end
    d
  end

  def ecommerce_on_render_post_type(d)
    # d = {post_type: @post_type, layout: (self.send :_layout), render: verify_template("post_type")}
    if d[:post_type].slug == 'commerce'
      ecommerce_add_assets_in_front
      d[:render] = "ecommerce/views/front/list_products"
    end
    d
  end
  def ecommerce_admin_list_post(d)
    if d[:post_type].slug == 'commerce'
      ecommerce_add_assets_in_front
      d[:render] = "ecommerce/views/admin/products/index"
    end
    d
  end

  def ecommerce_front_before_load

  end

  def ecommerce_admin_before_load
    # add menu bar
    pt = current_site.post_types.hidden_menu.where(slug: "commerce").first
    if pt.present?
      items_i = []
      items_i << {icon: "list", title: t('plugin.ecommerce.all_products'), url: admin_post_type_posts_path(pt.id)} if can? :posts, pt
      items_i << {icon: "plus", title: t('admin.post_type.add_new'), url: new_admin_post_type_post_path(pt.id)} if can? :create_post, pt
      if pt.manage_categories?
        items_i << {icon: "folder-open", title: t('admin.post_type.categories'), url: admin_post_type_categories_path(pt.id)} if can? :categories, pt
      end
      if pt.manage_tags?
        items_i << {icon: "tags", title: t('admin.post_type.tags'), url: admin_post_type_post_tags_path(pt.id)} if can? :post_tags, pt
      end
      items_i << {icon: "reorder", title: "#{t('plugin.ecommerce.orders')} <div class=\"informer informer-success\">#{current_site.orders.size}</div>", url: admin_plugins_ecommerce_orders_path}
      items_i << {icon: "money", title: t('plugin.ecommerce.tax_rates'), url: admin_plugins_ecommerce_tax_rates_path}
      items_i << {icon: "taxi", title: t('plugin.ecommerce.shipping_methods'), url: admin_plugins_ecommerce_shipping_methods_path}
      items_i << {icon: "credit-card", title: t('plugin.ecommerce.payment_methods'), url: admin_plugins_ecommerce_payment_methods_path}
      items_i << {icon: "tag", title: t('plugin.ecommerce.coupons'), url: admin_plugins_ecommerce_coupons_path}

      items_i << {icon: "cogs", title: t('admin.button.settings'), url: admin_plugins_ecommerce_settings_path}

      admin_menu_insert_menu_after("content", "e-commerce", {icon: "shopping-cart", title: t('plugin.ecommerce.e_commerce'), url: "", items: items_i}) if items_i.present?
    end

    # add assets admin
    append_asset_libraries({ecommerce: {css: ["/assets/plugins/ecommerce/assets/css/admin"], js: ["/assets/plugins/ecommerce/assets/js/admin"]}})

  end

  def ecommerce_app_before_load
    Site.class_eval do
      #attr_accessible :my_id
      has_many :carts, :class_name => "Plugins::Ecommerce::Models::Cart", foreign_key: :parent_id, dependent: :destroy
      has_many :orders, :class_name => "Plugins::Ecommerce::Models::Order", foreign_key: :parent_id, dependent: :destroy
      has_many :payment_methods, :class_name => "Plugins::Ecommerce::Models::PaymentMethod", foreign_key: :parent_id, dependent: :destroy
      has_many :shipping_methods, :class_name => "Plugins::Ecommerce::Models::ShippingMethod", foreign_key: :parent_id, dependent: :destroy
      has_many :coupons, :class_name => "Plugins::Ecommerce::Models::Coupon", foreign_key: :parent_id, dependent: :destroy
      has_many :tax_rates, :class_name => "Plugins::Ecommerce::Models::TaxRate", foreign_key: :parent_id, dependent: :destroy
    end

    SiteDecorator.class_eval do
      def current_unit
        @current_unit ||= h.e_get_currency_units[object.meta[:_setting_ecommerce][:current_unit]]['symbol'] rescue '$'
      end
      def currency_code
        @currency_code ||= h.e_get_currency_units[object.meta[:_setting_ecommerce][:current_unit]]['code'] rescue 'USD'
      end
      def current_weight
        @current_weight ||= h.e_get_currency_weight[object.meta[:_setting_ecommerce][:current_weight]]['code'] rescue 'kg'
      end
    end

    PostDecorator.class_eval do
      def the_sku
        object.get_field_value('ecommerce_sku').to_s
      end
      def the_price
        "#{h.current_site.current_unit} #{object.get_field_value('ecommerce_price').to_f}"
      end
      def the_weight
        "#{h.current_site.current_weight} #{object.get_field_value('ecommerce_weight').to_f}"
      end
      def the_qty
        object.get_field_value('ecommerce_qty') || 0
      end
      def the_photos
        object.get_field_values('ecommerce_photos') || []
      end
      def in_stock?
        object.get_field_value('ecommerce_stock').to_s.to_bool
      end
      def the_stock_status
        if in_stock? && the_qty_real.to_i > 0
          "<span class='label label-success'>#{I18n.t('plugin.ecommerce.product.in_stock')}</span>"
        else
          "<span class='label label-danger'>#{I18n.t('plugin.ecommerce.product.not_in_tock')}</span>"
        end
      end

      def featured?
        object.get_field_value('ecommerce_featured').to_s.to_bool
      end
      def the_featured_status
        if featured?
          "<span class='label label-primary'>#{I18n.t('plugin.ecommerce.product.featured')}</span>"
        else
          ""
        end
      end

      def the_qty_real
        object.get_field_value('ecommerce_qty') || 0
      end
    end


  end

  # here all actions on plugin destroying
  # plugin: plugin model
  def ecommerce_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def ecommerce_on_active(plugin)
    generate_custom_field_products

    unless ActiveRecord::Base.connection.table_exists? 'plugins_order_details'
      Plugins::Ecommerce::Models::Order.where("1 = 1").delete_all
      ActiveRecord::Base.connection.create_table :plugins_order_details do |t|
        t.integer :order_id
        t.string :customer, :email, :phone
        t.datetime :received_at, :accepted_at, :shipped_at, :closed_at
        t.timestamps
      end
    end

    #ActiveRecord::Base.connection.execute('create table plugins_shopping_carts(id int not null, user_id int not null, site_id int not null, created_at timestamp, updated_at timestamp, PRIMARY KEY (id));')
    #ActiveRecord::Base.connection.execute('create table plugins_shopping_cart_items(id int not null, cart_id int not null, product_id int not null, site_id int not null, shopping_cart_item_fields text, created_at timestamp, updated_at timestamp, PRIMARY KEY (id));')

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def ecommerce_on_inactive(plugin)

  end

  def get_commerce_post_type
    @ecommerce = current_site.post_types.hidden_menu.where(slug: "commerce").first
    unless @ecommerce.present?
      @ecommerce = current_site.post_types.hidden_menu.new(slug: "commerce", name: "Product")
      if @ecommerce.save
        @ecommerce.set_meta('_default', {
                                          has_category: true,
                                          has_tags: true,
                                          not_deleted: true,
                                          has_summary: true,
                                          has_content: true,
                                          has_comments: false,
                                          has_picture: true,
                                          has_template: false,
                                      })
        @ecommerce.categories.create({name: 'Uncategorized', slug: 'Uncategorized'.parameterize})
      end

    end

  end

  def ecommerce_add_assets_in_front
    append_asset_libraries({ecommerce: {css: ["/assets/plugins/ecommerce/assets/css/front"], js: ["/assets/plugins/ecommerce/assets/js/cart"]}})
  end

  private
  def generate_custom_field_products
    get_commerce_post_type
    unless @ecommerce.get_field_groups.where(slug: "plugin_ecommerce_product_data").present?
      @ecommerce.get_field_groups.destroy_all
      group = @ecommerce.add_custom_field_group({name: 'Products Details', slug: 'plugin_ecommerce_product_data'})
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.sku')", "slug"=>"ecommerce_sku"}, {field_key: "text_box", required: true})
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.attrs')", "slug"=>"ecommerce_attrs"}, {field_key: "field_attrs", required: false, multiple: true, false: true })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.photos')", "slug"=>"ecommerce_photos"}, {field_key: "image", required: false, multiple: true })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.price')", "slug"=>"ecommerce_price", "description" => "eval('\"Current unit: \" + h.current_site.current_unit.to_s')"}, {field_key: "numeric", required: true })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.tax')", "slug"=>"ecommerce_tax"}, {field_key: "select_eval", required: false, command: "options_from_collection_for_select(current_site.tax_rates.all, \"id\", \"the_name\")" })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.weight')", "slug"=>"ecommerce_weight", "description" => "eval('\"Current weight: \" + h.current_site.current_weight.to_s')"}, {field_key: "text_box", required: true })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.stock')", "slug"=>"ecommerce_stock"}, {field_key: "checkbox", default: true })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.qty')", "slug"=>"ecommerce_qty"}, {field_key: "numeric", required: true })
      group.add_manual_field({"name"=> "t('plugin.ecommerce.product.featured')", "slug"=>"ecommerce_featured"}, {field_key: "checkbox", default: true })
    end
  end

end