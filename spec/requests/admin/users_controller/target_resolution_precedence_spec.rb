# frozen_string_literal: true

require 'rails_helper'

# The canonical helper resolves params[:user_id] before params[:id]. These specs pin which value
# wins on each route family, from the perspective of a caller entitled to manage users.
#
# The ordering is what makes the nested updated_ajax route safe: there the path segment lands in
# params[:user_id] and is therefore not attacker-controllable. On the member routes the ordering
# inverts which key is authoritative, so an injected user_id takes precedence over the path
# segment. That is not an escalation — the filter and the lookup still resolve the same user, and
# this caller may edit either — but it is observable, so it is pinned here rather than left implicit.
RSpec.describe 'target resolution precedence', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user, site: current_site, role: 'admin',
                  password: 'admin_secret', password_confirmation: 'admin_secret')
  end
  let(:user_a) { create(:user, site: current_site, role: 'client', first_name: 'UserA') }
  let(:user_b) { create(:user, site: current_site, role: 'client', first_name: 'UserB') }
  let(:password_target) do
    create(:user, site: current_site, role: 'client',
                  password: 'old_secret', password_confirmation: 'old_secret')
  end

  before do
    post cama_admin_login_path, params: { user: { username: admin_user.username, password: 'admin_secret' } }
  end

  context 'without an injected key on a member route' do
    it 'resolves the path segment' do
      patch "/admin/users/#{user_a.id}", params: { user: { first_name: 'Edited' } }

      expect(user_a.reload.first_name).to eq('Edited')
    end
  end

  context 'with an injected user_id on a member route' do
    it 'resolves the injected value in preference to the path segment' do
      patch "/admin/users/#{user_a.id}?user_id=#{user_b.id}", params: { user: { first_name: 'Edited' } }

      expect(user_b.reload.first_name).to eq('Edited')
      expect(user_a.reload.first_name).to eq('UserA')
    end
  end

  # This is the example that actually discriminates on target resolution for impersonate. The
  # non-admin impersonate examples in member_route_target_resolution_spec.rb cannot: they are
  # gated by `cannot :impersonate` in the ability, which denies them whichever user resolves.
  # An admin holds `can :manage, :all`, so only the resolved target decides the outcome here.
  context 'with an injected user_id on the impersonate route' do
    it 'switches the session to the injected user rather than the path segment' do
      get "/admin/users/#{user_a.id}/impersonate?user_id=#{user_b.id}"

      expect(cookies[:auth_token]).to include(user_b.auth_token)
      expect(cookies[:auth_token]).not_to include(user_a.auth_token)
    end
  end

  context 'without an injected key on the nested updated_ajax route' do
    it 'resolves the path segment' do
      patch "/admin/users/#{password_target.id}/updated_ajax",
            params: { password: { password: 'new_secret', password_confirmation: 'new_secret' } }

      expect(response).to have_http_status(:no_content)
      expect(password_target.reload.authenticate('new_secret')).to be_truthy
      expect(password_target.reload.authenticate('old_secret')).to be_falsey
    end
  end
end
