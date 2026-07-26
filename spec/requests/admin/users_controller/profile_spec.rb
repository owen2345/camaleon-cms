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

    # The denial must not double as an existence oracle: a rejected caller has to get
    # the same response whether or not the requested id resolves to a real user, so
    # these variants are compared against each other rather than asserted individually.
    it 'denies existing, nonexistent and non-numeric ids identically' do
      variants = [admin_user.id, 999_999, 'abc']

      results = variants.map do |user_id|
        get cama_admin_profile_path, params: { user_id: user_id }
        [response.status, response.location]
      end

      expect(results.uniq.size).to eq(1)
      expect(response).to redirect_to(cama_admin_dashboard_path)
    end
  end

  context 'when an authorized user requests an unresolvable user_id' do
    before do
      post cama_admin_login_path, params: { user: { username: admin_user.username, password: 'admin_secret' } }
    end

    it 'redirects with a not found error for a nonexistent id' do
      get cama_admin_profile_path, params: { user_id: 999_999 }
      expect(response).to redirect_to(cama_admin_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.users.message.error'))
    end

    it 'redirects with a not found error for a non-numeric id' do
      get cama_admin_profile_path, params: { user_id: 'abc' }
      expect(response).to redirect_to(cama_admin_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.users.message.error'))
    end

    it 'redirects with a not found error for an array id' do
      get cama_admin_profile_path, params: { user_id: %w[1] }
      expect(response).to redirect_to(cama_admin_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.users.message.error'))
    end
  end
end
