FactoryBot.define do
  factory :post_type, class: CamaleonCms::PostType do
    name { Faker::Name.unique.name }
    sequence(:slug) { |n| "posttyp#{n}" }
    description { Faker::Lorem.sentence }
    data_options {}
    site
  end
end