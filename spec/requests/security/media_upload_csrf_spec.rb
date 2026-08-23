# frozen_string_literal: true

# Security (audit 2026-08-11 M7): media#upload carried
# `skip_before_action :verify_authenticity_token, only: :upload`, so a forged cross-site POST could
# drive a signed-in admin's browser to upload arbitrary files with no CSRF token. The skip is gone;
# the multipart uploader (jQuery uploadFile, which posts outside jquery_ujs' ajax prefilter) now
# carries the token as an `authenticity_token` form field. Forgery protection is disabled globally
# in the test env, so these examples enable it to exercise the real check; sign_in_as authenticates
# through the auth_token cookie, which the CSRF check does not touch.
RSpec.describe 'Security: media#upload requires a CSRF token (M7)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user_admin, site: current_site, password: 'longenough1', password_confirmation: 'longenough1')
  end

  around do |example|
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  before { sign_in_as(admin_user, site: current_site) }

  it 'rejects an upload POST that carries no CSRF token' do
    expect do
      post '/admin/media/upload', params: { file_upload: 'x' }
    end.to raise_error(ActionController::InvalidAuthenticityToken)
  end

  it 'still serves the media browser over GET (the read path is unaffected)' do
    get '/admin/media'

    expect(response).to have_http_status(:ok)
  end
end
