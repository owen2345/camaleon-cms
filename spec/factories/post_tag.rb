FactoryBot.define do
  factory :post_tag, class: CamaleonCms::PostTag do
    name { Faker::Name.unique.name }
    sequence(:slug) { |n| "tag-#{n}" }
    description { Faker::Lorem.sentence }
    data_options {}
    post_type
  end
end