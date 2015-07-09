class Plugins::Ecommerce::Models::TaxRate < TermTaxonomy
  default_scope { where(taxonomy: :ecommerce_tax_rate) }
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id
  scope :actives, -> {where(status: '1')}

  def the_name
    "#{name} (#{options[:rate]}%)"
  end

end