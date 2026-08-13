# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M14): login_post ran `@user&.authenticate`, so a missing username skipped
# bcrypt entirely and answered far faster than a wrong password for a real username -- a timing oracle
# for valid usernames. The controller now spends one bcrypt comparison on the missing-username branch
# too. Asserted by the hash comparison happening (deterministic) rather than by wall-clock time.
RSpec.describe 'Security: login timing enumeration (M14)', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let!(:admin) do
    create(:user_admin, site: site, username: 'timing-admin',
                        password: 'timing-pass-1', password_confirmation: 'timing-pass-1')
  end

  it 'compares the password against a bcrypt hash even when the username does not exist' do
    # is_password? is the actual hash comparison a real authenticate performs; building the failed-login
    # user computes a digest (BCrypt::Password.create) but never compares one, so this is 0 on the
    # unfixed missing-username path and >= 1 once the timing equalizer runs.
    expect_any_instance_of(BCrypt::Password).to receive(:is_password?).at_least(:once).and_call_original

    post cama_admin_login_path, params: { user: { username: 'no-such-user', password: 'whatever' } }
  end

  it 'still authenticates a real user with the correct password' do
    post cama_admin_login_path, params: { user: { username: admin.username, password: 'timing-pass-1' } }

    expect(cookies[:auth_token]).to be_present
  end
end
