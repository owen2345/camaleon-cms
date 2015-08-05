=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
#encoding: utf-8
module Plugins::Ecommerce::EcommerceFunctionsHelper
  def self.included(klass)
    klass.helper_method [:e_get_currency_units, :e_get_currency_weight, :e_symbol_by_code] rescue ""
  end
  def e_get_currency_weight
    r = {}
    JSON.parse('[{"code":"kg","name":'+"#{t('plugin.ecommerce.select.kilogram').to_json}"'},{"code":"lb","name":'+"#{t('plugin.ecommerce.select.pound').to_json}"'},{"code":"dr","name":'+"#{t('plugin.ecommerce.select.dram').to_json}"'},{"code":"gr","name":'+"#{t('plugin.ecommerce.select.grain').to_json}"'},{"code":"g","name":'+"#{t('plugin.ecommerce.select.gram').to_json}"'},{"code":"UK","name":'+"#{t('plugin.ecommerce.select.hundredweight').to_json}"'},{"code":"mg","name":'+"#{t('plugin.ecommerce.select.milligram').to_json}"'},{"code":"oz","name":'+"#{t('plugin.ecommerce.select.ounce').to_json}"'},{"code":"t","name":'+"#{t('plugin.ecommerce.select.tonne').to_json}"'}]').collect do |item|
      item['name'] = item['name'].to_s.titleize
      r[item['code']] = item
    end
    @e_get_currency_weight ||= r
  end

  def e_get_currency_units
    file = File.read("#{File.dirname(__FILE__)}/config/currency_#{I18n.locale.to_s}.json")
    @e_get_currency_units ||= JSON.parse(file)
  end

  def e_symbol_by_code(unit)
    e_get_currency_units[unit]['symbol'] rescue '$xx'
  end

  # use in add cart
  def e_add_data_product(data, product_id)
    post = Post.find(product_id).decorate
    attributes = post.attributes
    attributes[:content] = ''
    data[:product_title] = post.the_title
    data[:price] = post.get_field_value(:ecommerce_price)
    data[:weight] = post.get_field_value(:ecommerce_weight)
    data[:tax_rate_id] = post.get_field_value(:ecommerce_tax)
    tax_product = current_site.tax_rates.find(data[:tax_rate_id]).options[:rate].to_f  rescue 0
    data[:tax_percent] = tax_product
    data[:tax] = data[:price].to_f * data[:tax_percent] / 100 rescue 0
    data[:currency_code] = current_site.currency_code
    data.merge(post: attributes, fields: post.get_field_values_hash, meta: post.meta)
  end
end