# frozen_string_literal: true

require 'rails_helper'

# H7: validate_role's self-exemption (?user_id == the caller) is only meaningful for member actions
# that resolve a single target user. The collection actions (index/new/create) resolve no such target,
# so a self-referential ?user_id= must not exempt them from the :manage, :users capability check.
# The member self-exemption itself is left intact (see the "member self-service" context and the
# member_route_target_resolution spec). No stubs: the real filter has to run.
RSpec.describe 'users collection authorization', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:manager) do
    create(:user, site: current_site, role: 'admin',
                  password: 'manager_secret', password_confirmation: 'manager_secret')
  end
  let(:low_priv) do
    create(:user, site: current_site, role: 'client',
                  password: 'password', password_confirmation: 'password')
  end

  def login(user, password)
    post cama_admin_login_path, params: { user: { username: user.username, password: password } }
  end

  context 'when a low-privilege caller injects their own id as user_id on a collection action' do
    before { login(low_priv, 'password') }

    it 'denies the user index instead of rendering the user table' do
      get "/admin/users?user_id=#{low_priv.id}"

      expect(response).to redirect_to(cama_admin_dashboard_path)
    end

    it 'denies the new-user form' do
      get "/admin/users/new?user_id=#{low_priv.id}"

      expect(response).to redirect_to(cama_admin_dashboard_path)
    end

    it 'denies account creation and creates no user' do
      expect do
        post "/admin/users?user_id=#{low_priv.id}",
             params: { user: { username: 'injected_admin', email: 'injected@example.test',
                               password: 'password123', password_confirmation: 'password123' } }
      end.not_to change(CamaleonCms::User, :count)

      expect(response).to redirect_to(cama_admin_dashboard_path)
    end
  end

  context 'without the injected user_id (control: already denied)' do
    before { login(low_priv, 'password') }

    it 'denies the bare user index' do
      get '/admin/users'

      expect(response).to redirect_to(cama_admin_dashboard_path)
    end
  end

  context 'when the caller holds :manage, :users' do
    before { login(manager, 'manager_secret') }

    it 'lists users' do
      get '/admin/users'

      expect(response).to have_http_status(:ok)
    end

    it 'creates a user' do
      expect do
        post '/admin/users',
             params: { user: { username: 'legit_new', email: 'legit@example.test',
                               password: 'password123', password_confirmation: 'password123' } }
      end.to change(CamaleonCms::User, :count).by(1)
    end
  end

  context "when a member action targets the caller's own record (self-service preserved)" do
    before { login(low_priv, 'password') }

    it 'lets a low-privilege user change their own password via updated_ajax' do
      patch "/admin/users/#{low_priv.id}/updated_ajax",
            params: { password: { password: 'new password', password_confirmation: 'new password' } }

      expect(response).to have_http_status(:no_content)
      expect(low_priv.reload.authenticate('new password')).to be_truthy
    end
  end
end
