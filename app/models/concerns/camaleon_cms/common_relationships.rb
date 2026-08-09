# frozen_string_literal: true

module CamaleonCms
  module CommonRelationships
    extend ActiveSupport::Concern
    # rubocop:disable Rails/InverseOf

    included do
      # Scopes use the demodulized class name (the 2.9.2 contract every install's rows were
      # written under): 'Post', 'Main' for Widget::Main, and 'User' for a host Admin::User.
      # to_s tolerates anonymous subclasses (STI specs build them), whose name is nil.
      object_class_name = name.to_s.demodulize
      has_many :metas, -> { where(object_class: object_class_name) },
               class_name: 'CamaleonCms::Meta', foreign_key: :objectid, dependent: :destroy

      has_many :custom_field_values, -> { where(object_class: object_class_name) },
               class_name: 'CamaleonCms::CustomFieldsRelationship', foreign_key: :objectid, dependent: :delete_all

      # No dependent: on the definition associations (2.9.2 behavior). Teardown is owned by
      # CustomFieldsRead#_destroy_custom_field_groups, which runs first and destroys groups WITH
      # callbacks; a dependent here is inert at best, and on hook-less includers (PostComment) a
      # delete_all removed group rows while orphaning their fields and option metas. A :destroy
      # cascade is no alternative: custom_fields matches group rows too (same table, same scope)
      # but its CustomField typing would skip group teardown.
      # rubocop:disable Rails/HasManyOrHasOneDependent
      has_many :custom_fields, -> { where(object_class: object_class_name) },
               class_name: 'CamaleonCms::CustomField', foreign_key: :objectid

      # valid only for simple groups and not for complex like: posts, post, ... where the group is for individual or
      # children groups
      has_many :custom_field_groups, -> { where(object_class: object_class_name) },
               class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :objectid
      # rubocop:enable Rails/HasManyOrHasOneDependent
    end
    # rubocop:enable Rails/InverseOf
  end
end
