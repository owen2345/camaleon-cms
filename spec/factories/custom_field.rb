# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field, class: CamaleonCms::CustomField do
    object_class { '_fields' }
    name { Faker::Job.title }
    sequence(:slug) { |i| "field-#{i}" }
    custom_field_group
    field_order { 1 }
    is_repeat { false }
    transient do
      field_kind { 'text_box' }
    end
    settings {
      CamaleonCms::Admin::CustomFieldsHelper.cama_custom_field_settings[field_kind.to_sym]
    }
  end
end
