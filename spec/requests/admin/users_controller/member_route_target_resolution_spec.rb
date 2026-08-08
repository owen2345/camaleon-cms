# frozen_string_literal: true

require 'rails_helper'

# The member routes (/admin/users/:id) carry the path segment in params[:id], which makes
# params[:user_id] the injectable key here — the mirror image of the nested updated_ajax route,
# where the path segment lands in params[:user_id] and params[:id] is the injectable one.
#
# These specs pin the invariant that validate_role and set_user resolve the target through the
# same canonical helper, so a parameter-confusion pivot can never mutate a record the
# authorization filter did not authorize. No stubs: the real filter has to run.
RSpec.describe 'member route target resolution', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user, site: current_site, role: 'admin',
                  password: 'admin_secret', password_confirmation: 'admin_secret')
  end
  # Victim carries a known first_name so an unwanted write is visible
  let(:victim) { create(:user, site: current_site, role: 'client', first_name: 'Original') }
  # Attacker (low-privilege)
  let(:attacker) do
    create(:user, site: current_site, role: 'client', first_name: 'Attacker',
                  password: 'password', password_confirmation: 'password')
  end

  before do
    post cama_admin_login_path, params: { user: { username: attacker.username, password: 'password' } }
  end

  context 'when a low-privilege caller injects their own id as user_id' do
    it 'writes only their own record, never the user named in the path' do
      patch "/admin/users/#{victim.id}?user_id=#{attacker.id}", params: { user: { first_name: 'Pwned' } }

      expect(victim.reload.first_name).to eq('Original')
      expect(attacker.reload.first_name).to eq('Pwned')
    end

    it 'deletes neither the user named in the path nor themselves' do
      delete "/admin/users/#{victim.id}?user_id=#{attacker.id}"

      expect(victim.class.exists?(victim.id)).to be(true)
      expect(attacker.class.exists?(attacker.id)).to be(true)
    end

    it 'cannot impersonate the admin named in the path' do
      get "/admin/users/#{admin_user.id}/impersonate?user_id=#{attacker.id}"

      expect(response).to redirect_to(cama_admin_dashboard_path)
      expect(cookies[:auth_token]).not_to include(admin_user.auth_token)
      expect(session[:parent_auth_token]).to be_blank
    end
  end

  context 'when the injected user_id is not a scalar' do
    it 'updates the user named in the path with no server error' do
      post cama_admin_login_path, params: { user: { username: admin_user.username, password: 'admin_secret' } }

      patch "/admin/users/#{victim.id}?user_id[]=#{attacker.id}", params: { user: { first_name: 'ByAdmin' } }

      expect(victim.reload.first_name).to eq('ByAdmin')
      expect(attacker.reload.first_name).to eq('Attacker')
    end

    it 'resolves a self-edit to the path target instead of denying it' do
      patch "/admin/users/#{attacker.id}?user_id[]=#{victim.id}", params: { user: { first_name: 'SelfEdit' } }

      expect(attacker.reload.first_name).to eq('SelfEdit')
      expect(victim.reload.first_name).to eq('Original')
    end
  end

  context 'when a low-privilege caller targets another user directly' do
    it 'denies a member-route edit and leaves the target unchanged' do
      patch "/admin/users/#{victim.id}", params: { user: { first_name: 'Pwned' } }

      expect(response).to redirect_to(cama_admin_dashboard_path)
      expect(victim.reload.first_name).to eq('Original')
    end

    it 'denies impersonation with no injected parameter' do
      get "/admin/users/#{admin_user.id}/impersonate"

      expect(response).to redirect_to(cama_admin_dashboard_path)
      expect(cookies[:auth_token]).not_to include(admin_user.auth_token)
      expect(session[:parent_auth_token]).to be_blank
    end
  end
end
