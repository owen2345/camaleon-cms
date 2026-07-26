source 'https://rubygems.org'

gemspec

# TEMPORARY — remove once cama_contact_form 0.1.10 is published to RubyGems.
# RubyGems still serves 0.1.0 (2022-12-27), which carries the output-escaping vulnerability, so the
# gemspec's `~> 0.1.0` would otherwise resolve the unfixed gem and the regression specs could not run.
# Pinned to the immutable release tag rather than a branch, so the resolved revision cannot move.
# Revert to the plain gemspec dependency after publication — openspec/changes/fix-contact-form-output-escaping, D6.
gem 'cama_contact_form', git: 'https://github.com/owen2345/cama_contact_form', tag: '0.1.10'

gem 'non-digest-assets', '2.6.0'
gem 'rails', '~> 8.1.0'
gem 'selenium-webdriver'
gem 'sprockets-rails', '>= 3.5.2'

gem 'capybara-screenshot'

gem 'rspec_junit_formatter'

gem 'factory_bot_rails'
gem 'faker'
gem 'puma'
gem 'rack_session_access'
