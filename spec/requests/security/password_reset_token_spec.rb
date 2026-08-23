# frozen_string_literal: true

# Regression: on Rails 7.1+ has_secure_password generates a `password_reset_token` instance method that
# shadows Camaleon's same-named DB column. The mailer emitted the method's signed token while
# SessionsController#forgot looked the account up by the column, so every emitted reset link
# dead-ended on "URL incorrect". The fix reads the column explicitly on both sides (works on Rails
# 6.1–8.1), scopes to the current site, expires, is single-use, and rejects a blank password.
RSpec.describe 'Password reset token validation', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:user) { create(:user, site: current_site, password: 'oldpassword12', password_confirmation: 'oldpassword12') }

  # Requests a reset for `user` and returns the `h` token the mailer actually embedded in the link.
  def emitted_reset_token
    captured = nil
    allow_any_instance_of(CamaleonCms::Admin::SessionsController).to receive(:send_email) do |_ctrl, *args|
      extra_data = args.last
      captured = Rack::Utils.parse_query(URI.parse(extra_data[:url]).query)['h']
    end
    post cama_admin_forgot_path, params: { user: { email: user.email } }
    captured
  end

  describe 'an emailed reset link resolves to its account' do
    it 'presents the reset form for the account the link was emailed to' do
      token = emitted_reset_token
      expect(token).to be_present

      get cama_admin_forgot_path(h: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('user[password]')
    end

    it 'refuses a token that matches no account' do
      get cama_admin_forgot_path(h: 'not-a-real-token')

      expect(response).to redirect_to(cama_admin_forgot_path)
    end

    it 'does not present a reset form for a blank token' do
      get cama_admin_forgot_path(h: '')

      expect(response.body).not_to include('user[password_confirmation]')
    end
  end

  describe 'reset links expire' do
    it 'refuses a link older than the expiry window' do
      token = emitted_reset_token
      user.update_columns(password_reset_sent_at: 3.hours.ago) # rubocop:disable Rails/SkipsModelValidations

      get cama_admin_forgot_path(h: token)

      expect(response).to redirect_to(cama_admin_login_path)
    end
  end

  describe 'reset links are single-use' do
    it 'cannot be replayed after a successful reset' do
      token = emitted_reset_token

      post cama_admin_forgot_path(h: token),
           params: { user: { password: 'brandnewpass1', password_confirmation: 'brandnewpass1' } }
      expect(response).to redirect_to(cama_admin_login_path)
      expect(user.reload.authenticate('brandnewpass1')).to be_truthy

      # Replay the same link with a different password — must not take effect.
      post cama_admin_forgot_path(h: token),
           params: { user: { password: 'replayed12345', password_confirmation: 'replayed12345' } }

      expect(user.reload.authenticate('replayed12345')).to be_falsey
      expect(user.authenticate('brandnewpass1')).to be_truthy
    end
  end

  describe 'a blank password is not accepted as a successful reset' do
    it 'does not report success and leaves the password unchanged' do
      token = emitted_reset_token

      post cama_admin_forgot_path(h: token), params: { user: { password: '', password_confirmation: '' } }

      expect(response).not_to redirect_to(cama_admin_login_path)
      expect(user.reload.authenticate('oldpassword12')).to be_truthy
    end
  end

  describe 'a malformed password is not accepted as a successful reset' do
    it 'rejects an array-shaped password without consuming the reset link' do
      token = emitted_reset_token

      post cama_admin_forgot_path(h: token),
           params: { user: { password: ['sneakyarray12'], password_confirmation: ['sneakyarray12'] } }

      expect(response).not_to redirect_to(cama_admin_login_path)
      expect(user.reload.authenticate('oldpassword12')).to be_truthy
      # The link must survive the rejected attempt (a false success used to consume it).
      expect(user.read_attribute(:password_reset_token)).to eq(token)
    end

    it 'treats a scalar user param as an empty submission instead of failing' do
      token = emitted_reset_token

      post cama_admin_forgot_path(h: token), params: { user: 'foo' }

      expect(response).to have_http_status(:ok) # the reset form re-renders with an error
      expect(user.reload.authenticate('oldpassword12')).to be_truthy
    end
  end

  describe 'reset links are honored only for the account\'s own site' do
    # The site boundary only applies when users are not shared across sites (with users_share_sites
    # a user belongs to every site, so any site legitimately honors the token).
    it 'does not honor a token for an account on a different site (non-shared users)' do
      allow(PluginRoutes).to receive(:system_info)
        .and_return(PluginRoutes.system_info.merge('users_share_sites' => false))
      other_site = CamaleonCms::Site.create!(name: 'Other', slug: 'other-site', taxonomy: 'site')
      other_user = create(:user, site: other_site, password: 'oldpassword12', password_confirmation: 'oldpassword12')
      other_user.send_password_reset
      foreign_token = other_user.read_attribute(:password_reset_token)

      # Pin the request to the first site (Camaleon resolves the site by slug-as-host) so it runs in
      # that site's context; the token belongs to the other site and must not resolve here.
      host! current_site.slug
      get cama_admin_forgot_path(h: foreign_token)

      expect(response).to redirect_to(cama_admin_forgot_path)
    end
  end
end
