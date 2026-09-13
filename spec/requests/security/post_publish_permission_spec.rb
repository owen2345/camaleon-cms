# frozen_string_literal: true

# A user without the post type's publish permission must not be able to give a post the `published`
# status through any save path. `get_post_data` downgraded an explicit `status=published`, but the
# posts.status column defaults to `published`, so a create that omitted `post[status]` published
# anyway, and updating a post already in `draft` set `published` unconditionally when the status was
# left blank. The publish rule now runs on every status a save would give a post.
RSpec.describe 'Security: post publish permission', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:contributor) { create(:user, role: 'contributor', site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def create_post(user, params)
    sign_in_as(user, site: current_site)
    post "/admin/post_type/#{post_type.id}/posts", params: { post: params }
    post_type.posts.find_by(slug: params[:slug])
  end

  describe 'a contributor without the publish permission' do
    it 'gets pending, not published, when creating a post with no status' do
      record = create_post(contributor, { title: 'No status', slug: 'no-status', content: 'body' })

      expect(record.status).to eq('pending')
    end

    it 'cannot create a published post by naming the status explicitly' do
      record = create_post(contributor, { title: 'Explicit', slug: 'explicit', content: 'body', status: 'published' })

      expect(record.status).to eq('pending')
    end

    it 'cannot publish its own draft by updating it with no status' do
      draft = create(:post, post_type: post_type, owner: contributor, slug: 'own-draft', status: 'draft')
      sign_in_as(contributor, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{draft.id}",
            params: { post: { title: 'Own draft', content: 'body' } }

      expect(draft.reload.status).to eq('pending')
    end
  end

  describe 'an editor holding the publish permission' do
    it 'publishes a post created with no status (the column default is kept)' do
      record = create_post(editor, { title: 'Editor post', slug: 'editor-post', content: 'body' })

      expect(record.status).to eq('published')
    end

    it 'publishes its own draft on a blank-status update' do
      draft = create(:post, post_type: post_type, owner: editor, slug: 'editor-draft', status: 'draft')
      sign_in_as(editor, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{draft.id}",
            params: { post: { title: 'Editor draft', content: 'body' } }

      expect(draft.reload.status).to eq('published')
    end
  end
end
