# frozen_string_literal: true

require 'rails_helper'

# Audit M14 — logout must not rotate the impersonated user's token.
#
# cama_logout_user rotates cama_current_user's auth_token so a copied cookie cannot be replayed (M3).
# During impersonation cama_current_user is the impersonated (victim) user, so a full logout of the
# impersonated session (`/admin/logout?full=1`) would rotate the victim's per-user token and end their
# own sessions on every device. The rotation is skipped while an impersonation stash is present.
RSpec.describe 'Security: impersonation logout token rotation (M14)', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) do
    create(:user_admin, site: site, password: 'admin-pass-1', password_confirmation: 'admin-pass-1')
  end
  let(:target) do
    create(:user, site: site, password: 'target-pass-1', password_confirmation: 'target-pass-1')
  end

  def auth_token_in_jar
    cookies[:auth_token].to_s.split('&').first
  end

  it "does not rotate the impersonated user's token on a full logout during impersonation" do
    post cama_admin_login_path, params: { user: { username: admin.username, password: 'admin-pass-1' } }
    post impersonate_cama_admin_user_path(target)
    expect(auth_token_in_jar).to eq(target.auth_token) # browsing as the target
    target_token_before = target.reload.auth_token

    post cama_admin_logout_path, params: { full: 1 }

    expect(target.reload.auth_token).to eq(target_token_before)
  end

  it 'still rotates the token on an ordinary (non-impersonation) logout' do
    post cama_admin_login_path, params: { user: { username: admin.username, password: 'admin-pass-1' } }
    admin_token_before = admin.reload.auth_token

    post cama_admin_logout_path

    expect(admin.reload.auth_token).not_to eq(admin_token_before)
  end
end
