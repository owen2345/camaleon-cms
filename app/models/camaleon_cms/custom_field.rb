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

    # Scope metas by object_class. Meta rows are keyed by (objectid, object_class), so a custom
    # field whose numeric id collides with another model's id (e.g. a Post) would otherwise read
    # the wrong "_default" meta and lose its field_key. See regression: TinyMCE editor field
    # rendered as a plain text_box on Theme settings.
    # rubocop:disable Rails/InverseOf
    has_many :metas, -> { where(object_class: 'CustomField') }, foreign_key: :objectid, dependent: :destroy
    # rubocop:enable Rails/InverseOf
    has_many :values, class_name: 'CamaleonCms::CustomFieldsRelationship', dependent: :destroy

    belongs_to :custom_field_group, class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :parent_id,
                                    optional: true, inverse_of: :fields
    belongs_to :parent, class_name: 'CamaleonCms::CustomField', optional: true
    belongs_to :owner, polymorphic: true, foreign_key: :objectid, foreign_type: :object_class, optional: true

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
