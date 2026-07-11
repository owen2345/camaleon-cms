# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile request', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user, site: current_site, role: 'admin', password: 'admin_secret',
                  password_confirmation: 'admin_secret')
  end
  let(:regular_user) do
    create(:user, site: current_site, role: 'client', password: 'password',
                  password_confirmation: 'password')
  end
  let(:other_user) do
    create(:user, site: current_site, role: 'client', password: 'other_pass',
                  password_confirmation: 'other_pass')
  end

  context 'when viewing own profile' do
    before do
      post cama_admin_login_path, params: { user: { username: regular_user.username, password: 'password' } }
    end

    it 'renders own profile without user_id parameter' do
      get cama_admin_profile_path
      expect(response).to have_http_status(:ok)
    end

    it 'renders own profile with matching user_id' do
      get cama_admin_profile_path, params: { user_id: regular_user.id }
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when admin views another user' do
    before do
      post cama_admin_login_path, params: { user: { username: admin_user.username, password: 'admin_secret' } }
    end

    it 'renders the other users profile' do
      get cama_admin_profile_path, params: { user_id: regular_user.id }
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when non-admin tries to view another user' do
    before do
      post cama_admin_login_path, params: { user: { username: regular_user.username, password: 'password' } }
    end

    it 'denies access and redirects to dashboard' do
      get cama_admin_profile_path, params: { user_id: admin_user.id }
      expect(response).to redirect_to(cama_admin_dashboard_path)
      expect(flash[:error]).to be_present
    end
  end
end
