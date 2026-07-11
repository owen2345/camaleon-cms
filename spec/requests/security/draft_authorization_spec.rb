# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security: Draft Authorization', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:unauthorized_user) { create(:user, role: 'client', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first_or_create!(name: 'Post', site: current_site) }
  let(:published_post) do
    post_type.posts.create!(title: 'Test Post', slug: 'test-post', user_id: admin.id, status: 'published')
  end
  let!(:existing_draft) do
    post_type.posts.create!(
      title: 'Original Draft', slug: 'original-draft', content: 'Original content',
      user_id: admin.id, status: 'draft_child', post_parent: published_post.id
    )
  end

  before { allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site) }

  describe 'POST /admin/post_type/:post_type_id/drafts (#create)' do
    context 'when user is unauthorized' do
      before { sign_in_as(unauthorized_user, site: current_site) }

      it 'does not allow overwriting another user draft' do
        expect do
          post "/admin/post_type/#{post_type.id}/drafts", params: {
            post_id: published_post.id,
            post: { title: 'Hacked', content: 'Hacked content' }
          }
        end.not_to(change { existing_draft.reload.title })

        expect(existing_draft.reload.content).to eq('Original content')
      end

      it 'does not allow creating a new draft without permission' do
        expect do
          post "/admin/post_type/#{post_type.id}/drafts", params: {
            post: { title: 'New Draft', content: 'New content' }
          }
        end.not_to(change { current_site.posts.drafts.count })
      end

      it 'does not modify user_id on existing draft' do
        post "/admin/post_type/#{post_type.id}/drafts", params: {
          post_id: published_post.id,
          post: { title: 'Hacked', content: 'Hacked' }
        }
        expect(existing_draft.reload.user_id).to eq(admin.id)
      end
    end

    context 'when user is authorized' do
      before { sign_in_as(admin, site: current_site) }

      it 'overwrites existing draft for same post' do
        post "/admin/post_type/#{post_type.id}/drafts", params: {
          post_id: published_post.id,
          post: { title: 'Updated Draft', content: 'Updated content' }
        }
        expect(response).to have_http_status(:ok)
        expect(existing_draft.reload.title).to eq('Updated Draft')
        expect(existing_draft.reload.content).to eq('Updated content')
      end

      it 'preserves user_id when overwriting existing draft' do
        post "/admin/post_type/#{post_type.id}/drafts", params: {
          post_id: published_post.id,
          post: { title: 'Updated', content: 'Updated' }
        }
        expect(existing_draft.reload.user_id).to eq(admin.id)
      end

      it 'creates a new draft when no existing draft for post_id' do
        new_post = post_type.posts.create!(title: 'Another Post', slug: 'another-post', user_id: admin.id,
                                           status: 'published')

        expect do
          post "/admin/post_type/#{post_type.id}/drafts", params: {
            post_id: new_post.id,
            post: { title: 'New Draft', content: 'New content' }
          }
        end.to(change { current_site.posts.drafts.count }.by(1))

        json = JSON.parse(response.body)
        expect(json['draft']['id']).to be_present
      end

      it 'creates a new draft with current user as owner' do
        expect do
          post "/admin/post_type/#{post_type.id}/drafts", params: {
            post: { title: 'Fresh Draft', content: 'Fresh content' }
          }
        end.to(change { current_site.posts.drafts.count }.by(1))

        new_draft = current_site.posts.drafts.last
        expect(new_draft.user_id).to eq(admin.id)
      end
    end
  end

  describe 'PATCH /admin/post_type/:post_type_id/drafts/:id (#update)' do
    context 'when user is unauthorized' do
      before { sign_in_as(unauthorized_user, site: current_site) }

      it 'does not allow updating draft' do
        expect do
          patch "/admin/post_type/#{post_type.id}/drafts/#{existing_draft.id}", params: {
            post: { title: 'Hacked', content: 'Hacked content' }
          }
        end.not_to(change { existing_draft.reload.title })

        expect(existing_draft.reload.content).to eq('Original content')
      end

      it 'does not modify user_id' do
        patch "/admin/post_type/#{post_type.id}/drafts/#{existing_draft.id}", params: {
          post: { title: 'Hacked', content: 'Hacked' }
        }
        expect(existing_draft.reload.user_id).to eq(admin.id)
      end
    end

    context 'when user is authorized' do
      before { sign_in_as(admin, site: current_site) }

      it 'updates draft content' do
        patch "/admin/post_type/#{post_type.id}/drafts/#{existing_draft.id}", params: {
          post: { title: 'Updated Draft', content: 'Updated content' }
        }
        expect(response).to have_http_status(:ok)
        expect(existing_draft.reload.title).to eq('Updated Draft')
        expect(existing_draft.reload.content).to eq('Updated content')
      end

      it 'preserves user_id' do
        patch "/admin/post_type/#{post_type.id}/drafts/#{existing_draft.id}", params: {
          post: { title: 'Updated', content: 'Updated' }
        }
        expect(existing_draft.reload.user_id).to eq(admin.id)
      end
    end
  end

  describe 'cross-post-type access prevention' do
    let(:other_post_type) { create(:post_type, site: current_site) }

    before { sign_in_as(admin, site: current_site) }

    it 'create creates draft under the requested post type, not another post type' do
      other_post = other_post_type.posts.create!(
        title: 'Other Post', slug: 'other-post', user_id: admin.id, status: 'published'
      )

      expect do
        post "/admin/post_type/#{other_post_type.id}/drafts", params: {
          post_id: other_post.id,
          post: { title: 'New Under Other', content: 'Content' }
        }
      end.to(change { other_post_type.posts.drafts.count }.by(1))

      json = JSON.parse(response.body)
      new_draft = CamaleonCms::Post.find(json['draft']['id'])
      expect(new_draft.taxonomy_id).to eq(other_post_type.id)
      expect(new_draft.post_parent).to eq(other_post.id)
    end

    it 'update does not find draft from a different post type' do
      patch "/admin/post_type/#{other_post_type.id}/drafts/#{existing_draft.id}", params: {
        post: { title: 'Trying' }
      }
      # Rails rescues RecordNotFound — draft is unchanged
      expect(existing_draft.reload.title).to eq('Original Draft')
    end
  end

  describe 'post_parent validation' do
    before { sign_in_as(admin, site: current_site) }

    it 'sets post_parent when post_id references an existing post' do
      post "/admin/post_type/#{post_type.id}/drafts", params: {
        post_id: published_post.id,
        post: { title: 'Draft', content: 'Content' }
      }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      draft = CamaleonCms::Post.find(json['draft']['id'])
      expect(draft.post_parent).to eq(published_post.id)
    end

    it 'sets nil post_parent when post_id references non-existent post' do
      post "/admin/post_type/#{post_type.id}/drafts", params: {
        post_id: 999_999,
        post: { title: 'Orphan Draft', content: 'Content' }
      }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      draft = CamaleonCms::Post.find(json['draft']['id'])
      expect(draft.post_parent).to be_nil
    end

    it 'sets nil post_parent when post_id is absent' do
      post "/admin/post_type/#{post_type.id}/drafts", params: { post: { title: 'No Parent Draft', content: 'Content' } }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      draft = CamaleonCms::Post.find(json['draft']['id'])
      expect(draft.post_parent).to be_nil
    end
  end
end
