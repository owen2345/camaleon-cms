# frozen_string_literal: true

# Security (audit 2026-08-11 M16): the password-reset path clears its token on use, but
# SessionsController#confirm_email marked the email valid and left confirm_email_token in place, so
# the same confirmation link stayed live indefinitely. Impact is small (it only re-marks an
# already-valid email), but a one-time token must be single-use like the reset token. The token and
# its timestamp are now cleared on successful confirmation.
RSpec.describe 'Security: email-confirmation token is single-use (M16)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:user) { create(:user, site: current_site) }

  before do
    user.update_columns(confirm_email_token: 'tok123', confirm_email_sent_at: Time.current, # rubocop:disable Rails/SkipsModelValidations
                        is_valid_email: false)
  end

  it 'confirms the email and consumes the token' do
    get '/admin/confirm_email', params: { h: 'tok123' }

    user.reload
    expect(user.is_valid_email).to be_truthy
    expect(user.confirm_email_token).to be_nil
    expect(user.confirm_email_sent_at).to be_nil
  end

  it 'no longer resolves the account by the spent token' do
    get '/admin/confirm_email', params: { h: 'tok123' }

    expect(current_site.users.where(confirm_email_token: 'tok123')).not_to exist
  end
end
