class Plugins::Ecommerce::Models::OrderDetail < ActiveRecord::Base
  self.table_name = "plugins_order_details"
  attr_accessible :order_id, :customer, :email, :phone, :status, :received_at, :accepted_at, :shipped_at, :closed_at
  belongs_to :order, class_name: "Plugins::Ecommerce::Models::Order", foreign_key: :order_id
end
