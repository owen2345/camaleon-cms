# Force the test environment before Rails boots -- spec_helper (required just below) loads the dummy
# app's environment. An exported RAILS_ENV must never point the suite, whose before(:suite) purges
# every table, at a development or production database, so assign with `=`, not `||=`: an exported
# value must not win.
ENV['RAILS_ENV'] = 'test'

require 'spec_helper'

# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# This suite's factories live in the engine repo, but Rails.root is spec/dummy, so factory_bot_rails'
# root-relative defaults find nothing. Point factory_bot here explicitly and reload — the engine no
# longer injects its spec/factories into the host app (that auto-append aborted the boot of any host
# defining a same-named factory, and the packaged gem does not ship spec/ anyway). Same pattern as
# the cama_contact_form harness.
FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
FactoryBot.reload

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # include support helpers
  config.include CurrentSpecHelper

  config.include FactoryBot::Syntax::Methods
  config.before do
    # clear CurrentRequest before each example to avoid leakage
    CurrentRequest.reset
    # Clear the per-IP brute-force counters (H1) and the attack-plugin ban (H2) so cache state never
    # leaks between examples (all request specs share the 127.0.0.1 client IP and the same site). The
    # ban key is cleared here too, not just in a local after-hook, so an interrupted run cannot leave
    # a stale ban that breaks a later example.
    Rails.cache.delete_matched(/cama_captcha_attack|plugins_attack_ban/) if Rails.cache.respond_to?(:delete_matched)
    # Request specs leak the app's per-request locale: frontend locale resolution assigns
    # I18n.locale process-wide, so later examples otherwise run under whatever locale the last
    # request used (surfaced as es-locale "translation missing" in unrelated model specs).
    I18n.locale = I18n.default_locale
  end
end
