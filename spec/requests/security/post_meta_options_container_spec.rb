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
  include_context 'with the post editor'

  before { published_post.set_option('kept', 'yes') }

  def malformed(group)
    I18n.t('camaleon_cms.admin.post.message.malformed_group', group: group)
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

  # The store resolves a key under the database's collation: MySQL's defaults also fold accents
  # (`témplate` = `template` under general_ci, unicode_ci and 0900_ai_ci) and, on the UCA ones,
  # compatibility variants (`＿default` = `_default`), which no request-side folding reproduces. A key
  # that is not an ASCII word cannot be a spelling of a field the editor offers, so it is refused.
  describe 'a key that is not an ASCII word' do
    def not_a_field_name(key)
      I18n.t('camaleon_cms.admin.post.message.key_not_a_field_name', key: key)
    end

    it 'refuses an accented template key from an editor' do
      sign_in_as(editor, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                      meta: { 'témplate' => admin_view } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(not_a_field_name('meta[témplate]'))
      expect(stored_post.get_meta('template')).to be_blank
      expect(stored_post.get_meta('témplate')).to be_blank
      expect(stored_post.title).to eq(published_post.title)
    end

    it 'refuses a fullwidth underscore options key and keeps the options hash' do
      sign_in_as(editor, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                      meta: { '＿default' => 'replaced' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(not_a_field_name('meta[＿default]'))
      expect(stored_post.get_option('kept')).to eq('yes')
    end

    it 'refuses an accented counter key from an administrator' do
      sign_in_as(admin, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                      options: { 'vísits' => '9999' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(not_a_field_name('options[vísits]'))
      expect(stored_post.title).to eq(published_post.title)
    end

    it 'still stores an ASCII key with a dot, a dash and digits' do
      sign_in_as(editor, site: current_site)

      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                      meta: { 'plugin.field-2' => 'v' } }

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('plugin.field-2')).to eq('v')
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
