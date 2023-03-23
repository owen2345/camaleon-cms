# frozen_string_literal: true

module CamaleonCms
  module CommonRelationships
    extend ActiveSupport::Concern

    included do
      class_name = name.demodulize
      has_many :metas, -> { where(object_class: class_name) },
               class_name: 'CamaleonCms::Meta', foreign_key: :objectid, dependent: :destroy

      has_many :custom_field_values, -> { where(object_class: class_name) },
               class_name: 'CamaleonCms::CustomFieldsRelationship', foreign_key: :objectid, dependent: :delete_all

      has_many :custom_fields, -> { where(object_class: class_name) },
               class_name: 'CamaleonCms::CustomField', foreign_key: :objectid

      # valid only for simple groups and not for complex like: posts, post, ... where the group is for individual or
      # children groups
      has_many :custom_field_groups, -> { where(object_class: class_name) },
               class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :objectid
    end
  end
end
