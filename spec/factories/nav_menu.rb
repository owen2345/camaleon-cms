# frozen_string_literal: true

FactoryBot.define do
  factory :nav_menu, class: 'CamaleonCms::NavMenu' do
    name { Faker::Name.unique.name }
    slug { Faker::Internet.unique.slug }
    taxonomy { :nav_menu }
  end
end
