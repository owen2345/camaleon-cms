# frozen_string_literal: true

# The test environment raises an exception that no controller rescues. Production renders its error
# page instead: public/422.html, or a JSON body for a JSON request. This helper makes the app answer
# as in production for the duration of the block, for example a CSRF failure as a 422.
def with_production_error_pages
  env = Rails.application.env_config
  saved = env.slice('action_dispatch.show_exceptions', 'action_dispatch.show_detailed_exceptions')
  env['action_dispatch.show_exceptions'] = Rails::VERSION::STRING < '7.1' || :all
  env['action_dispatch.show_detailed_exceptions'] = false
  yield
ensure
  env.merge!(saved)
end
