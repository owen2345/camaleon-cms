# frozen_string_literal: true

# Admin responses must never be served from a browser or shared cache: they are per-user and
# dynamic, and a cached render can otherwise reappear after a server restart until a manual reload
# (the cold-boot blank-editor symptom). AdminController sends `Cache-Control: no-store` on every
# response via a before_action set ahead of authentication.
RSpec.describe 'Admin responses are never cached', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) { create(:user, site: site, role: 'admin') }

  it 'sends Cache-Control: no-store on an authenticated admin page' do
    sign_in_as(admin, site: site)

    get '/admin/dashboard'

    expect(response).to have_http_status(:ok)
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'sets no-store even on the pre-authentication redirect' do
    # The header is set before cama_authenticate, so an unauthenticated hit still carries it.
    get '/admin/dashboard'

    expect(response.headers['Cache-Control']).to include('no-store')
  end
end
