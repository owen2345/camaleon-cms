# frozen_string_literal: true

require 'rails_helper'

# Regression: cama_register_user fired its pre-hook via hook_run('user_before_register', r). hook_run's
# first argument is the target app, so the hook name was treated as a plugin and the call silently no-op'd
# (hook_run also never dispatches anonymous hooks) — a user_before_register handler never ran. It must
# broadcast like user_before_login / user_after_register.
RSpec.describe 'Registration user_before_register hook', type: :request do
  init_site

  before { CamaleonCms::Site.first.decorate.set_option('permit_create_account', true) }
  after  { (@ubr_ids || []).each { |id| PluginRoutes.remove_anonymous_hook('user_before_register', id) } }

  # Register an anonymous user_before_register handler that is torn down after the example.
  def add_ubr_hook(id, &block)
    (@ubr_ids ||= []) << id
    PluginRoutes.add_anonymous_hook('user_before_register', block, id)
  end

  def register!(username)
    post cama_admin_register_path, params: {
      user: { first_name: 'U', last_name: 'B', email: "#{username}@tester.com",
              username: username, password: 'password123', password_confirmation: 'password123' }
    }
  end

  it 'runs a registered user_before_register handler with the new (unsaved) user' do
    seen = []
    add_ubr_hook('spec_ubr') { |r| seen << r[:user]&.username }

    username = "ubr_#{Time.current.to_i}"
    register!(username)

    expect(seen).to include(username)
  end

  it 'lets a user_before_register handler veto the registration via stop_process' do
    add_ubr_hook('spec_ubr_stop') { |r| r[:stop_process] = true }

    username = "veto_#{Time.current.to_i}"
    register!(username)

    expect(CamaleonCms::User.find_by(username: username)).to be_nil
    expect(response).to have_http_status(:ok)
  end
end
