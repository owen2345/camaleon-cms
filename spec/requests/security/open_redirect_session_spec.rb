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
end
