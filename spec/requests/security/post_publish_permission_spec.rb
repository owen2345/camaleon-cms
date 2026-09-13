# frozen_string_literal: true

# A user without the post type's publish permission must not be able to give a post the `published`
# status through any save path. `get_post_data` downgraded an explicit `status=published`, but the
# posts.status column defaults to `published`, so a create that omitted `post[status]` published
# anyway, and updating a post already in `draft` set `published` unconditionally when the status was
# left blank. The publish rule now runs on every status a save would give a post.
#
# The rule compares the exact literal, and the column is stored verbatim: `post[status]=Published`
# (or `published `) reached the column, where MySQL's case-insensitive collation lists it among the
# published posts. A submitted status must now be exactly one the editor offers. A present-but-empty
# status on update was written as `''` (dropping the post from every tab); it now leaves the current
# status alone, as an absent one does.
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

  describe 'a status outside the editor set' do
    def not_offered
      I18n.t('camaleon_cms.admin.post.message.status_not_offered', field: 'post[status]')
    end

    it 'refuses a case variant from a contributor and creates nothing' do
      record = create_post(contributor, { title: 'Variant', slug: 'variant', content: 'body', status: 'Published' })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(not_offered)
      expect(record).to be_nil
    end

    it 'refuses a trailing-space variant and a payload from an editor, storing nothing' do
      published = create(:post, post_type: post_type, owner: editor, slug: 'editor-published', status: 'published')
      sign_in_as(editor, site: current_site)

      ['published ', "x'><script src=//evil.example/a.js></script>"].each do |status|
        patch "/admin/post_type/#{post_type.id}/posts/#{published.id}",
              params: { post: { title: 'Changed', content: 'body', status: status } }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(not_offered)
      end
      expect(published.reload.status).to eq('published')
      expect(published.title).not_to eq('Changed')
    end
  end

  describe 'a blank status on update' do
    it 'keeps a published post published' do
      published = create(:post, post_type: post_type, owner: editor, slug: 'stays-published', status: 'published')
      sign_in_as(editor, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{published.id}",
            params: { post: { title: 'Changed', content: 'body', status: '' } }

      expect(response).to have_http_status(:found)
      expect(published.reload.status).to eq('published')
      expect(published.title).to eq('Changed')
    end

    it 'promotes a draft through the publish rule, as omitting the status does' do
      editor_draft = create(:post, post_type: post_type, owner: editor, slug: 'editor-empty', status: 'draft')
      contributor_draft = create(:post, post_type: post_type, owner: contributor, slug: 'contrib-empty',
                                        status: 'draft')

      sign_in_as(editor, site: current_site)
      patch "/admin/post_type/#{post_type.id}/posts/#{editor_draft.id}",
            params: { post: { title: 'Editor draft', content: 'body', status: '' } }
      expect(editor_draft.reload.status).to eq('published')

      sign_in_as(contributor, site: current_site)
      patch "/admin/post_type/#{post_type.id}/posts/#{contributor_draft.id}",
            params: { post: { title: 'Contributor draft', content: 'body', status: '' } }
      expect(contributor_draft.reload.status).to eq('pending')
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
