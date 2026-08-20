# frozen_string_literal: true

FactoryBot.define do
  factory :nav_menu_item, class: 'CamaleonCms::NavMenuItem' do
    name { Faker::Name.name }
    url { 'https://example.com' }
    kind { 'external' }
    target { '' }
    taxonomy { :nav_menu_item }
  end
end
