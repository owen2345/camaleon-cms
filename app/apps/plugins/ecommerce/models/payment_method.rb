class Plugins::Ecommerce::Models::PaymentMethod < TermTaxonomy
  default_scope { where(taxonomy: :ecommerce_payment_method) }
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id

  scope :actives, -> {where(status: '1')}


end