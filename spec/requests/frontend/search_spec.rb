# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Frontend search', type: :request do
  init_site

  it 'renders the search results page' do
    get '/search', params: { q: 'anything' }, headers: { 'HTTP_HOST' => @site.slug }

    expect(response).to have_http_status(:ok)
  end

  it 'matches posts case-insensitively for non-ASCII queries' do
    # SQLite's LOWER()/LIKE are ASCII-only, so an uppercase Ü in the query can only
    # match the stored lowercase title when Ruby downcases the query before the SQL —
    # the same guarantee PostgreSQL installs need for plain ASCII queries.
    @site.post_types.find_by(slug: 'post')
         .add_post(title: 'über uns', slug: 'ueber-uns-search-fixture', content: 'search fixture content')

    get '/search', params: { q: 'ÜBER' }, headers: { 'HTTP_HOST' => @site.slug }

    expect(response.body).to include('über uns')
  end
end
