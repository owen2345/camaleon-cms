# frozen_string_literal: true

require 'rails_helper'

# H6 — Impersonation residue must not escalate a later login to admin.
#
# session_switch_user stashes the admin's raw auth cookie in
# session[:parent_auth_token], and session_back_to_parent restores it on
# /admin/logout for ANY signed-in user. Because a genuine sign-in never rotated
# the session, that stash outlived the admin: a different low-privileged user who
# signed in on the same browser inherited the admin's token and was handed it on
# logout, escalating to admin. A real sign-in (and a logout) must reset the
# session so the residue cannot cross an authentication boundary — while normal
# impersonation (switch, then return to the parent session) still works.
RSpec.describe 'Security: impersonation session reset (H6)', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) do
    create(:user_admin, site: site, password: 'admin-pass-1', password_confirmation: 'admin-pass-1')
  end
  let(:target) do
    create(:user, site: site, password: 'target-pass-1', password_confirmation: 'target-pass-1')
  end
  let(:attacker) do
    create(:user, site: site, password: 'attacker-pass-1', password_confirmation: 'attacker-pass-1')
  end

  # the token portion of the auth_token cookie, stored as "<token>&<user_agent>&<ip>"
  def auth_token_in_jar
    cookies[:auth_token].to_s.split('&').first
  end

  def login(user, password)
    post cama_admin_login_path, params: { user: { username: user.username, password: password } }
  end

  it 'does not let an abandoned impersonation escalate a later low-priv login on logout' do
    admin_token = admin.auth_token

    login(admin, 'admin-pass-1')
    get impersonate_cama_admin_user_path(target) # admin -> target; the admin token is stashed in the session
    expect(auth_token_in_jar).to eq(target.auth_token) # now browsing as the target

    # The admin walks away without returning to their own session; a different
    # low-privileged user then signs in with their own credentials on the same
    # browser. That genuine sign-in must drop the stale impersonation residue.
    login(attacker, 'attacker-pass-1')
    expect(auth_token_in_jar).to eq(attacker.auth_token)

    # Ending the session must log the attacker out — not restore the admin's cookie.
    get cama_admin_logout_path
    expect(auth_token_in_jar).not_to eq(admin_token)
  end

  it 'still returns the admin to their own session when they end impersonation' do
    admin_token = admin.auth_token

    login(admin, 'admin-pass-1')
    get impersonate_cama_admin_user_path(target)
    expect(auth_token_in_jar).to eq(target.auth_token)

    # The "return to parent" path is the same /admin/logout route while the
    # parent token is present: it must hand the admin back their own session.
    get cama_admin_logout_path
    expect(auth_token_in_jar).to eq(admin_token)
  end
end
