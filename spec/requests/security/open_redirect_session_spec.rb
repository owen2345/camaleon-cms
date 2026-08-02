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
end
