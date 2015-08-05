=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Models::CouponDecorator < TermTaxonomyDecorator
  delegate_all

  # Define presentation-specific methods here. Helpers are accessed through
  # `helpers` (aka `h`). You can override attributes, for example:
  #
  #   def created_at
  #     helpers.content_tag :span, class: 'time' do
  #       object.created_at.strftime("%a %m/%d/%y")
  #     end
  #   end

  def the_code
    object.slug.to_s.upcase
  end

  def the_amount
    opts = object.options
    case opts[:discount_type]
      when 'percent'
        "#{opts[:amount].to_f}%"
      when 'money'
        "#{the_symbol} #{opts[:amount].to_f}"
      else
        "Free Shipping"
    end
  end

  def the_symbol
    opts = object.options
    case opts[:discount_type]
      when 'percent'
        "%"
      when 'money'
        h.current_site.current_unit
      else
        ""
    end
  end

  def the_status
    opts = object.options
    if "#{opts[:expirate_date]} 23:59:59".to_datetime.to_i < Time.now.to_i
      "<span class='label label-danger'>#{I18n.t('plugin.ecommerce.table.expired')} </span>"
    elsif object.status.to_s.to_bool
      "<span class='label label-success'>#{I18n.t('plugin.ecommerce.active')} </span>"
    else
      "<span class='label label-default'>#{I18n.t('plugin.ecommerce.not_active')} </span>"
    end

  end
end
