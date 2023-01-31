# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field, class: CamaleonCms::Field do
    name { Faker::Job.title }
    sequence(:slug) { |i| "field-#{i}" }
    field_group { create(:custom_field_group) }
    position { 1 }
    transient do
      is_repeat { false }
      field_kind { 'text_box' }
    end
    settings {
      CamaleonCms::Admin::CustomFieldsHelper.cama_custom_field_settings[field_kind.to_sym]
    }
  end
end
