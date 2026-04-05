# frozen_string_literal: true

# Helper methods to set ActiveSupport::CurrentAttributes values in specs
module CurrentSpecHelper
  # Set current user for the duration of the example (or until reset)
  def store_current_user(user)
    CurrentRequest.user = user
  end

  # Set current site for the duration of the example (or until reset)
  def store_current_site(site)
    CurrentRequest.site = site
  end

  # Convenience: set both user and site
  def set_current(user: nil, site: nil)
    store_current_user(user) if user
    store_current_site(site) if site
  end

  # Sign in helper for request/controller specs: sets Current and the auth cookie when possible.
  def sign_in_as(user, site: nil)
    store_current_user(user)
    store_current_site(site || (user.respond_to?(:site) ? user.site : nil))
    # set cookie so cama_current_user can be resolved by auth token in request specs
    return unless defined?(cookies) && user.respond_to?(:auth_token)

    cookies[:auth_token] = "#{user.auth_token}&rspec&127.0.0.1"
  end

  # Reset Current to avoid leakage between examples
  def reset_current
    CurrentRequest.reset
  end
end
