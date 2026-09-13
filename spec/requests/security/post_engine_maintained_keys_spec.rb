# frozen_string_literal: true

# Some post metas and options are maintained by the engine itself: the `_default` meta holds the
# post's whole options hash, `visits` and `comments_count` are counters, and `status_default` /
# `draft_status` remember statuses. The save stored them from `meta[...]` / `options[...]` like any
# other key, so a request could replace the options hash (breaking the public page) or plant the
# status that `restore` later writes into the post.
RSpec.describe 'Security: engine-maintained post metas and options', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:contributor) { create(:user, role: 'contributor', site: current_site) }
  let!(:published_post) do
    post_type.posts.create!(title: 'Published post', slug: 'published-post', content: 'body',
                            user_id: admin.id, status: 'published')
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def refusal(key)
    I18n.t('camaleon_cms.admin.post.message.reserved_key', key: key)
  end

  def update_published_post(meta: {}, options: {})
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                    meta: meta, options: options }
  end

  def stored_post
    CamaleonCms::Post.find(published_post.id)
  end

  it 'refuses a submitted options hash, even from an administrator, and keeps the page working' do
    published_post.set_option('kept', 'yes')
    sign_in_as(admin, site: current_site)

    update_published_post(meta: { _default: 'replaced' })

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(refusal('meta[_default]'))
    expect(stored_post.get_option('kept')).to eq('yes')

    get '/published-post'
    expect(response).to have_http_status(:ok)
  end

  it 'refuses a restore status submitted by a contributor' do
    sign_in_as(contributor, site: current_site)

    post "/admin/post_type/#{post_type.id}/posts",
         params: { post: { title: 'Contributor post', slug: 'contributor-post', content: 'body' },
                   options: { status_default: 'published' } }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(refusal('options[status_default]'))
    expect(post_type.posts.find_by(slug: 'contributor-post')).to be_nil
  end

  {
    'meta[visits]' => { meta: { visits: '9999' } },
    'meta[comments_count]' => { meta: { comments_count: '9999' } },
    'options[draft_status]' => { options: { draft_status: 'published' } }
  }.each do |field, params|
    it "refuses #{field}" do
      sign_in_as(editor, site: current_site)

      update_published_post(**params)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(refusal(field))
      expect(stored_post.title).to eq('Published post')
    end
  end

  it 'keeps storing the metas and options plugins and themes submit' do
    sign_in_as(editor, site: current_site)

    update_published_post(meta: { product_specifications: 'Weight: 2kg' },
                          options: { seo_title: 'SEO title', hide_in_sitemap: '1' })

    expect(response).to have_http_status(:found)
    expect(stored_post.get_meta('product_specifications')).to eq('Weight: 2kg')
    expect(stored_post.get_option('seo_title')).to eq('SEO title')
    expect(stored_post.get_option('hide_in_sitemap')).to be_present
  end

  it 'still maintains the keys itself when a post is visited and trashed' do
    sign_in_as(admin, site: current_site)

    visits_before = stored_post.total_visits
    get '/published-post'
    expect(stored_post.total_visits).to eq(visits_before + 1)

    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}/trash"
    expect(stored_post.get_option('status_default')).to eq('published')
  end
end
