# frozen_string_literal: true

RSpec.describe 'Frontend HTML sitemap', type: :request do
  init_site

  it 'renders the category tree' do
    get '/sitemap.html', headers: { 'HTTP_HOST' => @site.slug }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Uncategorized')
  end
end
