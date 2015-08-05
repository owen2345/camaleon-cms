=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Models::OrderDecorator < TermTaxonomyDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def the_status
    case self.status
      when 'unpaid'
        "<span class='label label-danger'>#{I18n.t('plugin.ecommerce.select.unpaid')}</span>"
      when 'accepted'
        "<span class='label label-info'>#{I18n.t('plugin.ecommerce.select.accepted')}</span>"
      when 'shipped'
        "<span class='label label-primary'>#{I18n.t('plugin.ecommerce.select.shipped')}</span>"
      when 'closed'
        "<span class='label label-default'>#{I18n.t('plugin.ecommerce.select.closed')}</span>"
      when 'canceled'
        "<span class='label label-default'>#{I18n.t('plugin.ecommerce.select.canceled')}</span>"
      else
        "<span class='label label-success'>#{I18n.t('plugin.ecommerce.select.received')}</span>"
    end
  end

  def the_pay_status
    if object.paid?
      "<span class='label label-success'>#{I18n.t('plugin.ecommerce.select.received')}</span>"
    elsif object.canceled?
      "<span class='label label-default'>#{I18n.t('plugin.ecommerce.select.canceled')}</span>"
    else
      "<span class='label label-danger'>#{I18n.t('plugin.ecommerce.select.unpaid')}</span>"
    end
  end

  def the_url_tracking
    consignment_number = object.meta[:payment][:consignment_number] rescue 'none'
    object.shipping_method.options[:url_tracking].gsub("{{consignment_number}}", consignment_number) rescue "#{I18n.t('plugin.ecommerce.message.not_shipped')}"
  end
end
