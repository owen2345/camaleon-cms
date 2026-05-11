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

    has_many :metas, foreign_key: :objectid, dependent: :destroy, inverse_of: :owner
    has_many :values, class_name: 'CamaleonCms::CustomFieldsRelationship', dependent: :destroy

    belongs_to :custom_field_group, foreign_key: :objectid, optional: true, inverse_of: :fields
    belongs_to :parent, class_name: 'CamaleonCms::CustomField', optional: true
    belongs_to :owner, polymorphic: true, foreign_key: :objectid, foreign_type: :object_class

    validates :name, :object_class, presence: true
    validates :slug, uniqueness: { scope: %i[parent_id object_class],
                                   unless: ->(o) { o.is_a?(CamaleonCms::CustomFieldGroup) } }

    before_validation :before_validating
    before_update :check_select_eval_authorization

    private

    def before_validating
      self.slug ||= name
      self.slug = slug.to_s.parameterize
    end

    # Prevent unauthorized modification of field_key to select_eval
    def check_select_eval_authorization
      return unless respond_to?(:options) && options.present?

      # Check if field_key is being changed to select_eval
      return unless options[:field_key] == 'select_eval'
      # Allow if user has explicit permission
      return if can?(:manage, :select_eval)

      errors.add(:base, 'Not authorized to create or modify select_eval fields')
      throw :abort
    end
  end
end
