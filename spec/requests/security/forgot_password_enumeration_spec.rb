# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M13): the forgot-password endpoint returned a distinct message when the
# email matched an account versus not (a user-enumeration oracle), and re-sent a reset email on every
# request (a mail-bomb of a known inbox). It now answers with one neutral message either way, and
# throttles sends per account.
RSpec.describe 'Security: forgot-password enumeration and mail-bomb (M13)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let!(:user) do
    create(:user, site: current_site, email: 'reset-me@example.com',
                  password: 'oldpassword12', password_confirmation: 'oldpassword12')
  end

  def request_reset(email)
    post cama_admin_forgot_path, params: { user: { email: email } }
  end

  describe 'does not reveal whether an account exists' do
    it 'redirects with a neutral notice and no error for a known email' do
      request_reset(user.email)

      expect(response).to redirect_to(cama_admin_login_path)
      expect(flash[:notice]).to be_present
      expect(flash[:error]).to be_blank
    end

    it 'answers an unknown email identically to a known one' do
      request_reset('nobody@example.com')

      expect(response).to redirect_to(cama_admin_login_path)
      expect(flash[:notice]).to be_present
      expect(flash[:error]).to be_blank
    end
  end

  describe 'throttles reset emails per account' do
    it 'does not send a second reset email within the cooldown window' do
      sent = 0
      allow_any_instance_of(CamaleonCms::Admin::SessionsController).to receive(:send_email) { sent += 1 }

      request_reset(user.email)
      request_reset(user.email)

      expect(sent).to eq(1)
    end
  end
end
