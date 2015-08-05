=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Models::OrderDetail < ActiveRecord::Base
  self.table_name = "plugins_order_details"
  attr_accessible :order_id, :customer, :email, :phone, :status, :received_at, :accepted_at, :shipped_at, :closed_at
  belongs_to :order, class_name: "Plugins::Ecommerce::Models::Order", foreign_key: :order_id
end
