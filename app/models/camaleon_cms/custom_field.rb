module CamaleonCms
  class CustomField < CamaleonRecord
    include CamaleonCms::Metas

    self.primary_key = :id
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}custom_fields"

    alias_attribute :label, :name

    default_scope { order("#{CamaleonCms::CustomField.table_name}.field_order ASC") }
    scope :configuration, -> { where(parent_id: -1) }
    scope :visible_group, -> { where(status: nil) }

    # status: nil -> visible on list group fields
    # attr_accessible :object_class, :objectid, :description, :parent_id, :count, :name, :slug,
    # :field_order, :status, :is_repeat
    has_many :metas, -> { where(object_class: 'CustomField') }, foreign_key: :objectid, dependent: :destroy
    has_many :values, class_name: 'CamaleonCms::CustomFieldsRelationship',
                      foreign_key: :custom_field_id, dependent: :destroy
    belongs_to :custom_field_group, required: false
    belongs_to :parent, class_name: 'CamaleonCms::CustomField', foreign_key: :parent_id, required: false

    validates :name, :object_class, presence: true
    validates_uniqueness_of :slug, scope: %i[parent_id object_class],
                                   unless: ->(o) { o.is_a?(CamaleonCms::CustomFieldGroup) }

    before_validation :before_validating

    private

    def before_validating
      self.slug ||= name
      self.slug = slug.to_s.parameterize
    end
  end
end
