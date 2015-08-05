=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Models::Coupon < TermTaxonomy
  default_scope { where(taxonomy: :ecommerce_coupon) }
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id
  scope :actives, -> {where(status: '1')}

  def self.find_valid_by_code(code)
    coupon = self.find_by_slug(code.to_s.parameterize)
    if coupon.nil?
      nil
    elsif "#{coupon.options[:expirate_date]} 23:59:59".to_datetime.to_i < Time.now.to_i || coupon.status != '1'
      nil
    else
      coupon
    end
  end

end