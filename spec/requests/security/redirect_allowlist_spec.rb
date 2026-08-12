# frozen_string_literal: true

require 'rails_helper'

# The open-redirect policy is same-host-only by default, but legitimate off-site post-login/registration
# redirects (SSO, payment providers) can be permitted two ways, both fail-closed:
#   1. an admin/plugin allowlist of trusted hosts (redirect_allowed_hosts option + safe_redirect_hosts hook)
#   2. an explicit per-redirect opt-in from the hook (r[:allow_external_redirect]) for a fully-dynamic host
# Neither can smuggle a non-http scheme, and neither widens the caller-controlled return_to beyond trusted
# hosts.
RSpec.describe 'Security: trusted off-site redirects (allowlist + opt-in)', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:user) { create(:user, site: site, password: 'password', password_confirmation: 'password') }

  def sign_in!
    post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
  end

  # Wrap hooks_run so a named hook mutates its payload hash, mirroring how a plugin would.
  def stub_hook(hook_name)
    allow_any_instance_of(CamaleonCms::Admin::SessionsController)
      .to receive(:hooks_run).and_wrap_original do |orig, name, *rest|
        yield(rest.first) if name == hook_name && rest.first.is_a?(Hash)
        orig.call(name, *rest)
      end
  end

  describe 'host allowlist' do
    it 'follows a return_to on a host in the redirect_allowed_hosts option' do
      site.decorate.set_option('redirect_allowed_hosts', 'sso.example.com')
      sign_in!
      get cama_admin_login_path, params: { return_to: 'https://sso.example.com/callback' }

      expect(response).to have_http_status(:found)
      expect(response.location).to eq('https://sso.example.com/callback')
    end

    it 'compares allowlisted hosts case-insensitively and accepts a comma-separated list' do
      site.decorate.set_option('redirect_allowed_hosts', 'foo.example.com, SSO.EXAMPLE.COM')
      sign_in!
      get cama_admin_login_path, params: { return_to: 'https://sso.example.com/callback' }

      expect(response.location).to eq('https://sso.example.com/callback')
    end

    it 'follows a return_to on a host contributed by the safe_redirect_hosts hook' do
      stub_hook('safe_redirect_hosts') { |payload| payload[:hosts] << 'idp.example.com' }
      sign_in!
      get cama_admin_login_path, params: { return_to: 'https://idp.example.com/saml' }

      expect(response.location).to eq('https://idp.example.com/saml')
    end

    it 'still drops a non-allowlisted host when an allowlist is configured' do
      site.decorate.set_option('redirect_allowed_hosts', 'sso.example.com')
      sign_in!
      get cama_admin_login_path, params: { return_to: 'https://evil.com/phish' }

      expect(response.location).not_to include('evil.com')
      expect(response).to redirect_to(cama_admin_dashboard_path)
    end

    it 'does not let an allowlisted host smuggle a non-http scheme' do
      site.decorate.set_option('redirect_allowed_hosts', 'sso.example.com')
      sign_in!
      get cama_admin_login_path, params: { return_to: 'javascript://sso.example.com/%0aalert(1)' }

      expect(response.location).not_to include('javascript')
      expect(response).to redirect_to(cama_admin_dashboard_path)
    end
  end

  describe 'explicit allow_external opt-in from hooks' do
    it 'follows an off-site after_login destination the hook vouches for' do
      stub_hook('after_login') do |payload|
        payload[:redirect_to] = 'https://payments.example.net/checkout'
        payload[:allow_external_redirect] = true
      end
      sign_in!

      expect(response).to have_http_status(:found)
      expect(response.location).to eq('https://payments.example.net/checkout')
    end

    it 'follows an off-site user_registered destination the hook vouches for' do
      site.decorate.set_option('permit_create_account', true)
      stub_hook('user_registered') do |payload|
        payload[:redirect_url] = 'https://payments.example.net/checkout'
        payload[:allow_external_redirect] = true
      end

      username = "reg_#{Time.current.to_i}"
      post cama_admin_register_path, params: {
        user: { first_name: 'Reg', last_name: 'Test', email: "#{username}@tester.com",
                username: username, password: 'password123', password_confirmation: 'password123' }
      }

      expect(response.location).to eq('https://payments.example.net/checkout')
    end

    it 'does not follow an off-site destination when the hook sets no opt-in' do
      stub_hook('after_login') { |payload| payload[:redirect_to] = 'https://evil.com/phish' }
      sign_in!

      expect(response.location).not_to include('evil.com')
      expect(response).to redirect_to(cama_admin_dashboard_path)
    end

    it 'still rejects a non-http scheme even when the hook opts in' do
      stub_hook('after_login') do |payload|
        payload[:redirect_to] = 'javascript://www.example.com/%0aalert(document.domain)'
        payload[:allow_external_redirect] = true
      end
      sign_in!

      expect(response.location).not_to include('javascript')
      expect(response).to redirect_to(cama_admin_dashboard_path)
    end
  end
end
