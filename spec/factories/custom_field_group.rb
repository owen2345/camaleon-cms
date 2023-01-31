# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field_group, class: CamaleonCms::CustomFieldGroup do
    name { Faker::Job.title }
    sequence(:slug) { |i| "field-#{i}" }
    object_class { 'PostType_Post' }
    record { create(:post) }
    objectid { record.id }
    parent_id { record.post_type.site.id }
    field_order { 1 }
  end
end
