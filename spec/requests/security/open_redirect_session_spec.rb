# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security: Open Redirect in SessionHelper', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:user) { create(:user, site: site, password: 'password', password_confirmation: 'password') }

  it 'does not redirect to external URLs via return_to cookie' do
    post cama_admin_login_path,
         params: { user: { username: user.username, password: 'password' } },
         headers: { 'Cookie' => 'return_to=https://evil.com' }

    expect(response.location).not_to include('evil.com')
    expect(response).to redirect_to(cama_admin_dashboard_path)
  end

  it 'does not redirect to external URLs via return_to param on login when already signed in' do
    post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
    get cama_admin_login_path, params: { return_to: 'https://evil.com/path' }

    expect(response.location).not_to include('evil.com')
    expect(response).to redirect_to(cama_admin_dashboard_path)
  end

  it 'does not redirect to external URLs via return_to param on logout' do
    post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
    get cama_admin_logout_path, params: { return_to: 'https://evil.com/path' }

    expect(response.location).not_to include('evil.com')
    expect(response).to redirect_to(cama_admin_login_path)
  end

  describe 'same-host return_to destinations (host compared case-insensitively)' do
    it 'follows a mixed-case same-host return_to on login while signed in' do
      post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
      get cama_admin_login_path, params: { return_to: 'http://WWW.EXAMPLE.COM/admin/posts' }

      expect(response).to have_http_status(:found)
      expect(response.location).to eq('http://www.example.com/admin/posts')
    end

    it 'follows a mixed-case same-host return_to cookie after login' do
      post cama_admin_login_path,
           params: { user: { username: user.username, password: 'password' } },
           headers: { 'Cookie' => 'return_to=http://WWW.EXAMPLE.COM/admin/posts' }

      expect(response).to have_http_status(:found)
      expect(response.location).to eq('http://www.example.com/admin/posts')
    end

    it 'follows a mixed-case same-host return_to on logout' do
      post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
      get cama_admin_logout_path, params: { return_to: 'http://WWW.EXAMPLE.COM/admin/login' }

      expect(response).to have_http_status(:found)
      expect(response.location).to eq('http://www.example.com/admin/login')
    end

    it 'follows a relative return_to' do
      post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
      get cama_admin_login_path, params: { return_to: '/admin/posts' }

      expect(response).to have_http_status(:found)
      expect(response.location).to end_with('/admin/posts')
    end
  end

  # A destination whose parsed host is blank is not necessarily same-origin: a scheme
  # (https:evil.com, javascript:...), a protocol-relative form (///evil.com), or an encoded
  # slash/backslash lead (/%5cevil.com) still resolves off-site or trips the redirect backstop.
  # The old check only rejected destinations with a non-blank, mismatched host.
  describe 'host-blank destinations that are not safe local paths' do
    ['///evil.com', 'https:evil.com', 'javascript:alert(document.domain)', '/%5cevil.com'].each do |evil|
      it "falls back to the dashboard for return_to=#{evil.inspect} on login" do
        post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
        get cama_admin_login_path, params: { return_to: evil }

        expect(response).to redirect_to(cama_admin_dashboard_path)
      end
    end

    it 'falls back to the login path for a host-blank return_to on logout' do
      post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
      get cama_admin_logout_path, params: { return_to: '///evil.com' }

      expect(response).to redirect_to(cama_admin_login_path)
    end
  end

  # A destination whose parsed host matches the request host is still unsafe when it carries a non-HTTP
  # scheme: javascript://www.example.com/... parses as "same host" but is not a real same-origin
  # navigation, so only an http(s) (or scheme-relative //host) same-host destination is followed.
  describe 'same-host destinations carrying a non-http scheme' do
    ['javascript://www.example.com/%0aalert(document.domain)', 'data://www.example.com/x'].each do |evil|
      it "falls back to the dashboard for return_to=#{evil.inspect} on login" do
        post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
        get cama_admin_login_path, params: { return_to: evil }

        expect(response).to redirect_to(cama_admin_dashboard_path)
      end
    end

    it 'still follows a scheme-relative same-host destination' do
      post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }
      get cama_admin_login_path, params: { return_to: '//www.example.com/admin/posts' }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('www.example.com/admin/posts')
    end
  end

  # login_user's explicit redirect_url argument (set by after_login hooks / downstream plugins) was
  # redirected without the host check that the return_to cookie already gets.
  describe 'explicit redirect_url argument to login_user' do
    it 'does not follow an off-site destination set by an after_login hook' do
      allow_any_instance_of(CamaleonCms::Admin::SessionsController)
        .to receive(:hooks_run).and_wrap_original do |orig, name, *rest|
          rest.first[:redirect_to] = 'https://evil.com/phish' if name == 'after_login' && rest.first.is_a?(Hash)
          orig.call(name, *rest)
        end

      post cama_admin_login_path, params: { user: { username: user.username, password: 'password' } }

      expect(response).to redirect_to(cama_admin_dashboard_path)
    end
  end

  # register feeds redirect_to the user_registered hook's redirect_url the same way login feeds the
  # after_login hook's, so an off-site value set there must be host-checked, not followed verbatim.
  describe 'explicit redirect_url from the user_registered hook on register' do
    before { CamaleonCms::Site.first.decorate.set_option('permit_create_account', true) }

    it 'does not follow an off-site destination set by a user_registered hook' do
      allow_any_instance_of(CamaleonCms::Admin::SessionsController)
        .to receive(:hooks_run).and_wrap_original do |orig, name, *rest|
          rest.first[:redirect_url] = 'https://evil.com/phish' if name == 'user_registered' && rest.first.is_a?(Hash)
          orig.call(name, *rest)
        end

      username = "reg_#{Time.current.to_i}"
      post cama_admin_register_path, params: {
        user: { first_name: 'Reg', last_name: 'Test', email: "#{username}@tester.com",
                username: username, password: 'password123', password_confirmation: 'password123' }
      }

      expect(response.location).not_to include('evil.com')
      expect(response).to redirect_to(cama_admin_login_path)
    end
  end
end
