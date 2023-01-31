FactoryBot.define do
  factory :category, class: CamaleonCms::Category do
    name { Faker::Name.unique.name }
    sequence(:slug) { |n| "category-#{n}" }
    description { Faker::Lorem.sentence }
    data_options {}
    post_type { parent&.post_type || build(:post_type) }

    trait :with_parent do
      parent { build(:category) }
      post_type { nil }
      after(:build) do |model|
        model.post_type ||= parent.post_type
      end
    end
  end
end