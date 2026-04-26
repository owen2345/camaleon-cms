# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::CategoriesController, '#set_category', type: :request do
  let(:site) { create(:site) }
  let(:post_type_a) { create(:post_type, site: site) }
  let(:post_type_b) { create(:post_type, site: site) }
  let!(:category_b) { CamaleonCms::Category.create!(name: 'Category B', site_id: site.id, parent_id: post_type_b.id, taxonomy: :category, status: post_type_b.id) }

  let(:role_a) { site.user_roles.create!(name: 'Role A', slug: 'role_a') }
  let(:user_a) { create(:user, site: site, role: role_a.slug) }

  before do
    role_a.set_meta("_manager_#{site.id}", { 'categories' => 1 })
    role_a.set_meta("_post_type_#{post_type_a.id}", { 'categories' => 1 })
  end

  describe 'PATCH #update' do
    context 'when user has permission for post_type_a but tries to modify category from post_type_b' do
      before do
        role_a.set_meta("_post_type_#{post_type_a.id}", { 'categories' => 1 })
        sign_in_as(user_a, site: site)
      end

      it 'prevents IDOR attack - category not found' do
        patch "/admin/post_type/#{post_type_a.id}/categories/#{category_b.id}", params: {
          category: { name: 'IDOR_MODIFIED' }
        }

        category_b.reload

        expect(category_b.name).not_to eq('IDOR_MODIFIED')
        expect(response).to redirect_to(/admin/)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when user has permission for post_type_a but tries to delete category from post_type_b' do
      before do
        role_a.set_meta("_post_type_#{post_type_a.id}", { 'categories' => 1 })
        sign_in_as(user_a, site: site)
      end

      it 'prevents IDOR attack - category not deleted' do
        expect do
          delete "/admin/post_type/#{post_type_a.id}/categories/#{category_b.id}"
        end.not_to(change { CamaleonCms::Category.exists?(category_b.id) })

        expect(response).to redirect_to(/admin/)
      end
    end
  end
end
