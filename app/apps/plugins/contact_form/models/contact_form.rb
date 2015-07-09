class Plugins::ContactForm::Models::ContactForm < ActiveRecord::Base
  attr_accessible :site_id, :name, :description, :count, :slug, :value, :settings, :parent_id

  belongs_to :site, class_name: "Site", foreign_key: :site_id
  belongs_to :post, class_name: "Post", foreign_key: :parent_id
  has_many :responses, :class_name => "Plugins::ContactForm::Models::ContactForm", :foreign_key => :parent_id, dependent: :destroy
  validates :name, presence: true
  validates_uniqueness_of :slug, scope: :site_id

  before_validation :before_validating

  private
  def before_validating
    slug = self.slug
    slug = self.name if slug.blank?
    self.slug = slug.to_s.parameterize
  end
end
