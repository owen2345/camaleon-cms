module CamaleonCms
  class CustomFieldsRelationship < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}custom_fields_relationships"

    # attr_accessible :objectid, :custom_field_id, :term_order, :value, :object_class,
    # :custom_field_slug, :group_number
    default_scope { order("#{CamaleonCms::CustomFieldsRelationship.table_name}.term_order ASC") }

    # relations
    belongs_to :custom_field, required: false

    # validates :objectid, :custom_field_id, presence: true
    validates :custom_field_id, presence: true # error on clone model

    after_save :set_parent_slug
    after_save :update_model_owner # TODO: convert this model into polymorphic

    private

    def set_parent_slug
      # self.update_column('custom_field_slug', self.custom_fields.slug)
    end

    # touch owner model
    def update_model_owner
      "CamaleonCms::#{object_class}".constantize.find(objectid).touch
    rescue StandardError
      nil
    end
  end
end
