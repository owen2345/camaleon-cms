# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field_value, class: CamaleonCms::FieldValue do
    field { create(:custom_field) }
    field_slug { field.slug }
    value { 'some value' }
    position { 0 }
    group_number { 0 }
    record { create(:post) }
  end
end
