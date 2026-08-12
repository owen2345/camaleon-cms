# frozen_string_literal: true

require 'rails_helper'

# Regression: cama_register_user fired its pre-hook via hook_run('user_before_register', r). hook_run's
# first argument is the target app, so the hook name was treated as a plugin and the call silently no-op'd
# (hook_run also never dispatches anonymous hooks) — a user_before_register handler never ran. It must
# broadcast like user_before_login / user_after_register.
RSpec.describe 'Registration user_before_register hook', type: :request do
  init_site

  before { CamaleonCms::Site.first.decorate.set_option('permit_create_account', true) }
  after  { PluginRoutes.remove_anonymous_hook('user_before_register', 'spec_ubr') }

  it 'runs a registered user_before_register handler with the new (unsaved) user' do
    seen = []
    PluginRoutes.add_anonymous_hook('user_before_register', ->(r) { seen << r[:user]&.username }, 'spec_ubr')

    username = "ubr_#{Time.current.to_i}"
    post cama_admin_register_path, params: {
      user: { first_name: 'U', last_name: 'B', email: "#{username}@tester.com",
              username: username, password: 'password123', password_confirmation: 'password123' }
    }

    expect(seen).to include(username)
  end
end
