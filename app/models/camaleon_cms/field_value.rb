# frozen_string_literal: true

module CamaleonCms
  class FieldValue < ActiveRecord::Base
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}field_values"
    include CamaleonCms::Metas

    belongs_to :field, optional: true, class_name: 'Field'
    belongs_to :record, polymorphic: true
    validates :field_slug, presence: true
    # validate_uniqueness :field_slug, scope: %i[field_slug]

    before_validation :retrieve_field, unless: :field, if: :field_slug
    scope :ordered, -> { order(position: :asc) }
    scope :group_order, -> { order(group_number: :asc) }


    private

    def retrieve_field
      self.field = record.fields.where(slug: field_slug).take if record.respond_to?(:fields)
    end
  end
end
