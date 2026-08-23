# frozen_string_literal: true

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
    post impersonate_cama_admin_user_path(target) # admin -> target; the admin token is stashed in the session
    expect(auth_token_in_jar).to eq(target.auth_token) # now browsing as the target

    # The admin walks away without returning to their own session; a different
    # low-privileged user then signs in with their own credentials on the same
    # browser. That genuine sign-in must drop the stale impersonation residue.
    login(attacker, 'attacker-pass-1')
    expect(auth_token_in_jar).to eq(attacker.auth_token)

    # Ending the session must log the attacker out — not restore the admin's cookie.
    post cama_admin_logout_path
    expect(auth_token_in_jar).not_to eq(admin_token)
  end

  it 'still returns the admin to their own session when they end impersonation' do
    admin_token = admin.auth_token

    login(admin, 'admin-pass-1')
    post impersonate_cama_admin_user_path(target)
    expect(auth_token_in_jar).to eq(target.auth_token)

    # Ending impersonation now re-authenticates the admin before restoring their
    # session (see impersonation_return_reauth_spec): the Logout link routes to the
    # confirmation, and the admin's password hands them back their own session.
    post cama_admin_logout_path
    expect(response).to redirect_to(cama_admin_back_to_parent_path)
    post cama_admin_back_to_parent_path, params: { password: 'admin-pass-1' }
    expect(auth_token_in_jar).to eq(admin_token)
  end

  it 'clears the stashed parent token when a real logout ends the session' do
    login(admin, 'admin-pass-1')
    post impersonate_cama_admin_user_path(target)
    expect(session[:parent_auth_token]).to be_present

    # Reaching cama_logout_user with the stash still present requires a request that is NOT
    # signed in — a signed-in impersonator is routed to session_back_to_parent, which deletes
    # the stash itself. An incomplete auth cookie de-authenticates the request; assigning it
    # (not cookies.delete, which leaves the jar unchanged in a request spec) forces that branch.
    cookies[:auth_token] = 'invalid'
    post cama_admin_logout_path
    expect(session[:parent_auth_token]).to be_nil
  end

  it 'clears the stashed parent token even when the de-authenticated request is a GET' do
    login(admin, 'admin-pass-1')
    post impersonate_cama_admin_user_path(target)
    expect(session[:parent_auth_token]).to be_present

    # The de-authenticated cleanup must run on ANY verb: a forged GET against a signed-out session
    # ends nothing, but a stale impersonation stash must still be cleared (H6). The early
    # `return cama_logout_user unless cama_sign_in?` applies regardless of verb -- pinned over GET so a
    # future reorder that moves the guard below the request.post? branch cannot reopen H6 for GET.
    cookies[:auth_token] = 'invalid'
    get cama_admin_logout_path
    expect(session[:parent_auth_token]).to be_nil
  end
end
