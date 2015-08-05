=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Models::ShippingMethod < TermTaxonomy
  default_scope { where(taxonomy: :ecommerce_shipping_method) }
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id

  scope :actives, -> {where(status: '1')}

  def get_price_from_weight(weight = 0)
    price_total = 0
    if meta[:prices].present?
      meta[:prices].each do |key, value|
        price_total = value[:price] if value[:min_weight].to_f <= weight.to_f && value[:max_weight].to_f >= weight.to_f
      end
    end
    price_total.to_f
  end


end