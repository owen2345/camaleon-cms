include CamaleonCms::SiteHelper
include CamaleonCms::HooksHelper

FactoryBot.define do
  factory :site, class: 'CamaleonCms::Site' do
    name { Faker::Name.unique.name }
    # Feature specs need the slug to match the Capybara server host so multi-site
    # resolution finds the site; elsewhere it only has to be unique, since a
    # suite-wide shared site already exists (see spec/support/shared_site.rb).
    sequence(:slug) do |n|
      current_session = Capybara.current_session
      current_session.server ? "#{current_session.server.host}:#{current_session.server.port}" : "test-site-#{n}"
    end
    description { Faker::Lorem.sentence }

    transient do
      theme { 'default' }
      skip_intro { true }
    end

    after(:create) do |site, evaluator|
      # site_after_install resolves current_site, which needs a request once a
      # second site exists; pin the new site as current for the install instead.
      previous_site = CurrentRequest.site
      CurrentRequest.site = site.decorate
      site_after_install(site, evaluator.theme)
      site.set_option('save_intro', true) if evaluator.skip_intro
      # harden-installer-default-admin: production mints a random admin password and forces a change
      # on first login. Reset the shared admin to the well-known credentials the suite signs in with
      # (admin/admin123) and clear the must-change marker so existing specs are unaffected. Specs that
      # exercise the new provisioning behavior create sites through the model directly, bypassing this.
      admin = site.users.where(role: 'admin').first
      if admin
        admin.update(password: 'admin123', password_confirmation: 'admin123')
        admin.delete_meta('must_change_password')
      end
    ensure
      CurrentRequest.site = previous_site
    end
  end
end
