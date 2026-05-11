# frozen_string_literal: true

module CamaleonCms
  module CommonRelationships
    extend ActiveSupport::Concern

    included do
      has_many :metas, class_name: 'CamaleonCms::Meta', foreign_key: :objectid, dependent: :destroy, inverse_of: :owner

      has_many :custom_field_values, class_name: 'CamaleonCms::CustomFieldsRelationship', foreign_key: :objectid,
                                     dependent: :delete_all, inverse_of: :owner

      has_many :custom_fields, class_name: 'CamaleonCms::CustomField', foreign_key: :objectid, inverse_of: :owner,
                               dependent: :delete_all

      # valid only for simple groups and not for complex like: posts, post, ... where the group is for individual or
      # children groups
      has_many :custom_field_groups, class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :objectid,
                                     inverse_of: :owner, dependent: :delete_all
    end
  end
end
