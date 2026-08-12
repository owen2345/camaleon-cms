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

  it 'does not double-render when a vetoing handler already performed the response' do
    # A manifest handler runs via `send` on the controller, so a veto may redirect itself (the
    # user_before_login convention). Rendering the form on top of that would raise DoubleRenderError.
    allow_any_instance_of(CamaleonCms::Admin::SessionsController)
      .to receive(:cama_register_user) do |controller, *_args|
        controller.redirect_to('/admin/login')
        { result: false, type: :stopped, user: CamaleonCms::Site.first.users.new }
      end

    register!('vetoredir')

    expect(response).to redirect_to('/admin/login')
  end

  it 'shows a generic error when a veto provides no feedback of its own' do
    add_ubr_hook('spec_ubr_stop_default') { |r| r[:stop_process] = true }

    register!("veto_default_#{SecureRandom.hex(4)}")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Registration could not be completed.')
  end

  it "shows the handler's own error instead of the generic one" do
    add_ubr_hook('spec_ubr_stop_custom') do |r|
      r[:user].errors.add(:base, 'Signups are paused')
      r[:stop_process] = true
    end

    register!("veto_custom_#{SecureRandom.hex(4)}")

    expect(response.body).to include('Signups are paused')
    expect(response.body).not_to include('Registration could not be completed.')
  end

  context 'with the registration captcha enabled (hook fires only past the captcha gate)' do
    before { CamaleonCms::Site.first.decorate.set_option('security_captcha_user_register', true) }

    it 'does not fire user_before_register when the captcha fails' do
      ran = []
      add_ubr_hook('spec_ubr_captcha') { |_r| ran << true }

      username = "capfail_#{Time.current.to_i}"
      register!(username) # no captcha submitted → verification fails before the hook

      expect(ran).to be_empty
      expect(CamaleonCms::User.find_by(username: username)).to be_nil
      # Prove the hook was skipped by the captcha gate (not merely absent): the captcha error rendered.
      expect(response.body).to include('Oh! Its error with CAPTCHA!')
    end

    it 'fires user_before_register once the captcha passes' do
      allow_any_instance_of(CamaleonCms::Admin::SessionsController)
        .to receive(:cama_captcha_verified?).and_return(true)
      ran = []
      add_ubr_hook('spec_ubr_pass') { |_r| ran << true }

      username = "cappass_#{Time.current.to_i}"
      register!(username)

      expect(ran).to eq([true])
      expect(CamaleonCms::User.find_by(username: username)).not_to be_nil
    end
  end
end
