include CamaleonCms::SiteHelper
include CamaleonCms::HooksHelper
FactoryBot.define do
  factory :site, class: CamaleonCms::Site do
    name { Faker::Name.unique.name }
    slug { Capybara.current_session.server ? "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}" : 'key' }
    # sequence(:slug) { |n| Capybara.current_session.server ? "#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}" : "site#{n}" }
    description { Faker::Lorem.sentence }
    transient do
      theme { PluginRoutes.all_themes.first['key'] }
      skip_intro { true }
    end
    after(:create) do |site, evaluator|
      site_after_install(site, evaluator.theme)
      site.set_option('save_intro', true) if evaluator.skip_intro
    end
  end
end