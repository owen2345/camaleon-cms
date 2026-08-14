# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M3): the auth_token cookie was set in the plain jar with no HttpOnly or
# Secure flag, and logout deleted the cookie without rotating the server-side token, so a copied cookie
# stayed valid after logout. The cookie is now HttpOnly and Secure-over-SSL, and logout rotates the
# token (which, being per-user, also ends the user's other sessions).
RSpec.describe 'Security: auth cookie hardening (M3)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let!(:admin) do
    create(:user_admin, site: current_site, username: 'cookie-admin',
                        password: 'cookie-pass-1', password_confirmation: 'cookie-pass-1')
  end

  def login
    post cama_admin_login_path, params: { user: { username: admin.username, password: 'cookie-pass-1' } }
  end

  def auth_set_cookie
    Array(response.headers['Set-Cookie']).flat_map { |c| c.to_s.split("\n") }.find { |c| c.start_with?('auth_token=') }
  end

  it 'sets the auth cookie HttpOnly' do
    login

    expect(auth_set_cookie).to match(/;\s*httponly/i)
  end

  it 'marks the auth cookie Secure over an SSL request' do
    https!
    login

    expect(auth_set_cookie).to match(/;\s*secure/i)
  end

  it 'does not mark the auth cookie Secure over plain HTTP so local development still works' do
    login

    expect(auth_set_cookie).not_to match(/;\s*secure/i)
  end

  it 'rotates the auth token on logout so a copied cookie cannot be replayed' do
    login
    token_before = admin.reload.auth_token

    post cama_admin_logout_path

    expect(admin.reload.auth_token).to be_present
    expect(admin.reload.auth_token).not_to eq(token_before)
  end

  # Audit M4: changing your own password rotates the token and re-issues the cookie; that re-issue
  # must keep the M3 hardening rather than write a bare cookie.
  it 're-issues the auth cookie HttpOnly when a user changes their own password' do
    login
    patch "/admin/users/#{admin.id}/updated_ajax",
          params: { password: { password: 'new-cookie-pass-2', password_confirmation: 'new-cookie-pass-2' } }

    expect(response).to have_http_status(:no_content)
    expect(auth_set_cookie).to match(/;\s*httponly/i)
  end
end
