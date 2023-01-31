# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field_group, class: CamaleonCms::FieldGroup do
    name { Faker::Job.title }
    sequence(:slug) { |i| "field-#{i}" }
    record { create(:post) }
    site { record.site }
    position { 1 }
  end
end
