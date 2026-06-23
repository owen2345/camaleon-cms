# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::CategoriesController, type: :request do
  let(:site) { create(:site) }
  let(:post_type) { create(:post_type, site: site) }
  let(:admin_user) do
    create(
      :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: site
    )
  end

  before do
    post_type.categories.create!(name: 'Test Category', slug: 'test-category')
    sign_in_as(admin_user, site: site)
  end

  describe 'GET /admin/post_type/:post_type_id/categories' do
    context 'with XHR and without cama_ajax_request parameter' do
      it 'renders without admin layout (no sidebar/header)' do
        get "/admin/post_type/#{post_type.id}/categories",
            headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('id="sidebar-menu"')
        expect(response.body).not_to include('nav-pills')
        expect(response.body).not_to include('<div class="wrapper">')
        expect(response.body).to include('Test Category')
      end
    end

    context 'with XHR and with cama_ajax_request parameter' do
      it 'renders with _ajax layout wrapper' do
        get "/admin/post_type/#{post_type.id}/categories",
            params: { cama_ajax_request: '1' },
            headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<section class="content" id="admin_content"')
        expect(response.body).not_to include('id="sidebar-menu"')
        expect(response.body).not_to include('<div class="wrapper">')
        expect(response.body).to include('Test Category')
      end
    end

    context 'with non-XHR request' do
      it 'renders with full admin layout' do
        get "/admin/post_type/#{post_type.id}/categories"

        expect(response).to have_http_status(:success)
        expect(response.body).to include('<div class="wrapper">')
        expect(response.body).to include('id="sidebar-menu"')
        expect(response.body).to include('nav-pills')
        expect(response.body).to include('<section class="content" id="admin_content"')
        expect(response.body).to include('Test Category')
      end
    end
  end
end
