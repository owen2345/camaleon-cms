# frozen_string_literal: true

# Security (audit 2026-08-11 M15): the User model only validated password presence (on create) and the
# 72-byte bcrypt maximum, so a one-character password was accepted. A minimum length is now enforced
# whenever a password is set, without forcing a password on an update that leaves it untouched.
RSpec.describe CamaleonCms::User, type: :model do
  init_site

  let(:site) { Cama::Site.first }

  describe 'password strength' do
    it 'rejects a password shorter than 8 characters' do
      user = build(:user, site: site, password: 'short12', password_confirmation: 'short12')

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'accepts a password of at least 8 characters' do
      user = build(:user, site: site, password: 'longenough', password_confirmation: 'longenough')

      expect(user).to be_valid
    end

    it 'does not require a password when updating a record without changing it' do
      user = create(:user, site: site, password: 'longenough', password_confirmation: 'longenough')

      user.first_name = 'Renamed'

      expect(user.save).to be(true)
    end
  end
end
