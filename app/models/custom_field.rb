class CustomField < ActiveRecord::Base
  include Metas
  has_many :metas, ->{ where(object_class: 'CustomField')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  self.table_name = "custom_fields"
  default_scope {order("custom_fields.field_order ASC")}
  # status: nil -> visible on list group fields
  attr_accessible :object_class, :objectid, :description, :parent_id, :count, :name, :slug, :field_order, :status, :is_repeat
  validates :name, :object_class, presence: true
  has_many :values, :class_name => "CustomFieldsRelationship", :foreign_key => :custom_field_id, dependent: :destroy
  belongs_to :custom_field_group, class_name: "CustomFieldGroup"
  belongs_to :parent, class_name: "CustomField", :foreign_key => :parent_id

  scope :configuration, -> {where(parent_id: -1)}
  scope :visible_group, -> {where(status: nil)}

  before_validation :before_validating

  private

  def before_validating
    self.slug = self.name if self.slug.blank?
    self.slug = self.slug.to_s.parameterize
  end


end
