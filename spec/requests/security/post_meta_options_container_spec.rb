# frozen_string_literal: true

# The save refuses reserved keys and (for non-admins) unoffered template/layout values by reading
# `params[:meta]` / `params[:options]` as a hash. But `set_metas` / `set_options` write whatever those
# params are, iterating them with `|key, value|`: an array of pairs (`meta[]=x`, or a JSON body
# `{"meta":[["template","..."]]}`) answers neither `keys` nor `key?`, so it slips past the checks yet is
# still written key by key -- clobbering the options hash, planting a reserved key, or pointing a
# non-admin's post at an admin view. An array `options` reaches `set_options`' `to_sym` and 500s.
# The save must refuse a `meta`/`options` param that is not a set of fields, before anything is written.
# The store also resolves a meta key with `where(key:)`, case- and trailing-space-insensitively on
# MySQL, so `meta[Template]` / `meta[VISITS]` must be matched against the same fields as their canonical
# spelling.
RSpec.describe 'Security: post meta/options request containers', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:admin_view) { 'camaleon_cms/admin/settings/site' }
  let!(:published_post) do
    create(:post, post_type: post_type, owner: admin, slug: 'published-post', status: 'published')
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    published_post.set_option('kept', 'yes')
  end

  def malformed(group)
    I18n.t('camaleon_cms.admin.post.message.malformed_group', group: group)
  end

  def stored_post
    CamaleonCms::Post.find(published_post.id)
  end

  def json_headers
    { 'CONTENT_TYPE' => 'application/json' }
  end

  def update_json(body)
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: { post: { title: 'Changed title', content: 'body', status: 'published' } }.merge(body).to_json,
          headers: json_headers
  end

  describe 'a non-hash meta container' do
    before { sign_in_as(editor, site: current_site) }

    it 'refuses a form array that would null the options hash, and stores nothing' do
      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: 'post[title]=Changed+title&post[content]=body&post[status]=published&meta[]=_default',
            headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(malformed('meta'))
      expect(stored_post.get_option('kept')).to eq('yes')
      expect(stored_post.title).to eq(published_post.title)
    end

    it 'refuses a JSON array of pairs that would point the post at an admin view' do
      update_json(meta: [['template', admin_view]])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(malformed('meta'))
      expect(stored_post.get_meta('template')).to be_blank
    end
  end

  describe 'a non-hash options container' do
    before { sign_in_as(editor, site: current_site) }

    it 'refuses it instead of 500ing in set_options' do
      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: 'post[title]=Changed+title&post[content]=body&post[status]=published&options[]=status_default',
            headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(malformed('options'))
    end
  end

  describe 'an administrator' do
    before { sign_in_as(admin, site: current_site) }

    it 'is refused a JSON array meta that would replace the options hash' do
      update_json(meta: [%w[_default replaced]])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(malformed('meta'))
      expect(stored_post.get_option('kept')).to eq('yes')
    end
  end

  describe 'a case- or space-variant key (matched as the canonical field)' do
    before { sign_in_as(editor, site: current_site) }

    it 'refuses meta[Template] naming an admin view' do
      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                      meta: { 'Template' => admin_view } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        I18n.t('camaleon_cms.admin.post.message.value_not_offered', field: 'meta[Template]')
      )
      expect(stored_post.get_meta('template')).to be_blank
    end

    it 'refuses the reserved counter under a variant spelling' do
      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                      meta: { 'VISITS' => '9999' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        I18n.t('camaleon_cms.admin.post.message.reserved_key', key: 'meta[VISITS]')
      )
    end
  end

  describe 'a blank template value' do
    before { sign_in_as(editor, site: current_site) }

    it 'is accepted when the field is submitted empty' do
      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: 'post[title]=Changed+title&post[content]=body&post[status]=published&meta[template]',
            headers: { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('template')).to be_blank
    end
  end

  describe 'a non-hash meta container on a draft save' do
    it 'is refused with a JSON error and stores nothing' do
      sign_in_as(editor, site: current_site)

      post "/admin/post_type/#{post_type.id}/drafts",
           params: { post_id: published_post.id, post: { title: 'Draft title' },
                     meta: [['template', admin_view]] }.to_json,
           headers: json_headers

      expect(JSON.parse(response.body)['error']).to include(malformed('meta'))
      expect(post_type.posts.drafts.where(post_parent: published_post.id)).to be_empty
    end
  end
end
