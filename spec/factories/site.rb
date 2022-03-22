# frozen_string_literal: true

include CamaleonCms::SiteHelper
include CamaleonCms::HooksHelper

FactoryBot.define do
  factory :site, class: CamaleonCms::Site do
    name { Faker::Name.unique.name }
    slug do
      current_session = Capybara.current_session
      current_session.server ? "#{current_session.server.host}:#{current_session.server.port}" : 'key'
    end
    # sequence(:slug) { |n| Capybara.current_session.server ? "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}" : "site#{n}" }
    description { Faker::Lorem.sentence }
    transient do
      theme { 'default' }
      skip_intro { true }
    end

    after(:create) do |site, evaluator|
      site_after_install(site, evaluator.theme)
      site.set_option('save_intro', true) if evaluator.skip_intro
    end
  end
end
