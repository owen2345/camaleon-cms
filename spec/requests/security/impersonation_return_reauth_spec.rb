# frozen_string_literal: true

require 'rails_helper'

# Returning from impersonation to the admin account must require the admin's own
# password (H6 residual). session_switch_user stashes the admin's auth cookie in
# session[:parent_auth_token], and returning restores it. Because the impersonated
# session an admin holds is byte-for-byte identical to one they abandon, no
# identity check can tell the admin apart from whoever later holds that browser —
# so the only proof of "I am the admin" is the admin's password. Without it, an
# admin who walks away from an active impersonation on a shared browser lets the
# next occupant restore the admin account by clicking the ordinary Logout link.
RSpec.describe 'Security: impersonation return requires re-auth', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) do
    # A distinctive username makes the "not disclosed in the page" assertion deterministic.
    create(:user_admin, site: site, username: 'zq-parent-admin',
                        password: 'admin-pass-1', password_confirmation: 'admin-pass-1')
  end
  let(:target) do
    create(:user, site: site, password: 'target-pass-1', password_confirmation: 'target-pass-1')
  end

  def auth_token_in_jar
    cookies[:auth_token].to_s.split('&').first
  end

  def login(user, password)
    post cama_admin_login_path, params: { user: { username: user.username, password: password } }
  end

  # Set up an active impersonation, then abandon it: the browser is authenticated
  # as the target and the session still carries the admin's stashed token.
  def impersonate_then_abandon
    login(admin, 'admin-pass-1')
    get impersonate_cama_admin_user_path(target)
    expect(auth_token_in_jar).to eq(target.auth_token)
  end

  it 'does not restore the admin from the plain Logout link without re-auth' do
    admin_token = admin.auth_token
    impersonate_then_abandon

    # The ordinary Logout link (a bare GET) must no longer hand back the admin's
    # session to whoever holds the abandoned impersonation; it routes to the
    # re-auth confirmation instead.
    get cama_admin_logout_path
    expect(response).to redirect_to(cama_admin_back_to_parent_path)
    follow_redirect!
    expect(auth_token_in_jar).not_to eq(admin_token)
  end

  it 'does not restore the admin when the password is wrong' do
    admin_token = admin.auth_token
    impersonate_then_abandon

    post cama_admin_back_to_parent_path, params: { password: 'not-the-admin-password' }

    expect(response).to have_http_status(:ok) # re-renders the form, does not restore
    expect(auth_token_in_jar).to eq(target.auth_token)
    expect(auth_token_in_jar).not_to eq(admin_token)
    # Impersonation stays active so the real admin can retry with the right password.
    expect(session[:parent_auth_token]).to be_present
  end

  it 'restores the admin only when the admin password is supplied' do
    admin_token = admin.auth_token
    impersonate_then_abandon

    post cama_admin_back_to_parent_path, params: { password: 'admin-pass-1' }

    expect(auth_token_in_jar).to eq(admin_token)
    expect(session[:parent_auth_token]).to be_nil
  end

  it 'lets the holder log out completely without restoring the admin' do
    admin_token = admin.auth_token
    impersonate_then_abandon

    get cama_admin_logout_path, params: { full: 1 }

    expect(auth_token_in_jar).not_to eq(admin_token)
    expect(session[:parent_auth_token]).to be_nil
  end

  it 'ends the session when the stashed token no longer resolves to the admin' do
    impersonate_then_abandon
    # Changing the admin's password rotates their auth_token, orphaning the stash.
    admin.update!(password: 'rotated-pass-9', password_confirmation: 'rotated-pass-9')

    get cama_admin_back_to_parent_path

    expect(response).to redirect_to(cama_admin_login_path)
    expect(session[:parent_auth_token]).to be_blank
    expect(auth_token_in_jar).to be_blank
  end

  it 'fails closed instead of erroring when the parent admin has no password digest' do
    impersonate_then_abandon
    # update_column skips validations and the token-rotation callback, so the stash still resolves
    # to the admin; only the digest is gone (reachable via custom user models or direct DB state).
    admin.update_column(:password_digest, nil) # rubocop:disable Rails/SkipsModelValidations

    post cama_admin_back_to_parent_path, params: { password: 'admin-pass-1' }

    expect(response).to redirect_to(cama_admin_login_path)
    expect(session[:parent_auth_token]).to be_blank
    expect(auth_token_in_jar).to be_blank
  end

  it 'renders the confirmation form without disclosing the admin username' do
    impersonate_then_abandon

    get cama_admin_back_to_parent_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(cama_admin_back_to_parent_path) # the password form posts back here
    expect(response.body).to include(cama_admin_logout_path(full: 1)) # the full-logout escape hatch
    # Whoever holds the abandoned session must not learn which admin account to attack.
    expect(response.body).not_to include(admin.username)
  end

  # Guessing the admin password through the confirmation must be throttled like the login form
  # itself: failures feed the same 'login' attack counter, and past the site's threshold a captcha
  # is required on top of the password. The counter lives in the same session as the parent stash,
  # so it cannot be reset without destroying the stash being attacked.
  describe 'brute-force protection' do
    let(:max_tries) { site.get_option('max_try_attack', 5).to_i }

    def wrong_guess
      post cama_admin_back_to_parent_path, params: { password: 'not-the-admin-password' }
    end

    it 'feeds failed attempts into the shared login attack counter' do
      impersonate_then_abandon
      counter_before = session['cama_captcha_login'].to_i

      2.times { wrong_guess }

      expect(session['cama_captcha_login'].to_i).to eq(counter_before + 2)
    end

    it 'requires a captcha past the threshold, even with the correct password' do
      admin_token = admin.auth_token
      impersonate_then_abandon

      (max_tries + 1).times { wrong_guess }
      post cama_admin_back_to_parent_path, params: { password: 'admin-pass-1' }

      # The correct password alone no longer restores; the form re-renders asking for a captcha.
      expect(auth_token_in_jar).to eq(target.auth_token)
      expect(auth_token_in_jar).not_to eq(admin_token)
      expect(response.body).to include('name="captcha"')
      # Impersonation stays active: the real admin can still return by also solving the captcha.
      expect(session[:parent_auth_token]).to be_present
    end

    it 'resets the counter on a successful return' do
      impersonate_then_abandon
      2.times { wrong_guess }

      post cama_admin_back_to_parent_path, params: { password: 'admin-pass-1' }

      expect(session['cama_captcha_login'].to_i).to eq(0)
    end
  end
end
