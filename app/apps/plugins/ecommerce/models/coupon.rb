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