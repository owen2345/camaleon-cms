# frozen_string_literal: true

require 'rails_helper'

# Crafted array/hash query params 500ed the admin post index for a fully authorized user:
#   ?q[]=x                                 -> Array#downcase NoMethodError
#   ?s[]=published                         -> no status case matches, then Array#to_sym NoMethodError
#   ?taxonomy=category&taxonomy_id[]=<id>  -> find(Array) returns an Array, which has no #decorate
# They carry no meaning, so the index treats them as absent.
RSpec.describe 'Admin posts index with array-typed params', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first_or_create!(name: 'Post', site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  it 'ignores an array q param' do
    get "/admin/post_type/#{post_type.id}/posts", params: { q: ['x'] }

    expect(response).to have_http_status(:ok)
  end

  it 'ignores an array s param and falls back to the published tab' do
    get "/admin/post_type/#{post_type.id}/posts", params: { s: ['published'] }

    expect(response).to have_http_status(:ok)
  end

  it 'ignores an array taxonomy_id param' do
    category = post_type.categories.create!(name: 'Robust Cat', slug: 'robust-cat')

    get "/admin/post_type/#{post_type.id}/posts",
        params: { taxonomy: 'category', taxonomy_id: [category.id] }

    expect(response).to have_http_status(:ok)
  end
end
