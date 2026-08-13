# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M12): two admin endpoints ran with no authorization.
#   * AdminController#search queried current_site.posts with no status filter and no permission check,
#     so any admin-area user (e.g. a client) could enumerate every post title/slug in every status.
#   * Posts::DraftsController#index rendered the post type as JSON with no authorize! call.
RSpec.describe 'Security: admin search and drafts authorization', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:client) { create(:user, role: 'client', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first_or_create!(name: 'Post', site: current_site) }
  let!(:unpublished_post) do
    post_type.posts.create!(title: 'SECRETDRAFT title', slug: 'secretdraft', user_id: admin.id, status: 'pending')
  end

  before { allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site) }

  describe 'GET /admin/search (content)' do
    it 'does not expose unpublished content to a user without content permissions' do
      sign_in_as(client, site: current_site)

      get '/admin/search', params: { q: 'secretdraft', kind: 'content' }

      expect(response.body).not_to include(unpublished_post.title)
    end

    it 'still returns matching content to an authorized admin' do
      sign_in_as(admin, site: current_site)

      get '/admin/search', params: { q: 'secretdraft', kind: 'content' }

      expect(response.body).to include(unpublished_post.title)
    end
  end

  describe 'GET /admin/post_type/:post_type_id/drafts (#index)' do
    it 'denies a user without :posts permission on the post type' do
      sign_in_as(client, site: current_site)

      get "/admin/post_type/#{post_type.id}/drafts"

      # CanCan::AccessDenied is rescued into a dashboard redirect, not a JSON render
      expect(response).to have_http_status(:found)
    end

    it 'allows an authorized admin' do
      sign_in_as(admin, site: current_site)

      get "/admin/post_type/#{post_type.id}/drafts"

      expect(response).to have_http_status(:ok)
    end
  end
end
