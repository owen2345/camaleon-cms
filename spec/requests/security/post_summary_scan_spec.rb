# frozen_string_literal: true

# `meta[summary]` is post content: the engine's default theme renders the excerpt through `raw` on
# listing and search pages, and any theme without its own list partial falls back to it. The save
# stored it from any user without the scan that gates `content` (a model validation on the content
# column, which a meta row never passes through), so an editor without the unfiltered-content
# permission could store a script that ran on every listing. The summary is now held to the same
# scan as the content, in the request check that runs before anything is written: refused for a
# user without `post_content_unfiltered_html`, stored as written for a permission holder, and never
# rewritten.
RSpec.describe 'Security: post summary scan', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:script) { '<p>Intro</p><script>alert("summary")</script>' }
  let!(:published_post) do
    create(:post, post_type: post_type, owner: admin, title: 'Published post', slug: 'published-post',
                  status: 'published')
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def update_summary(summary)
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                    meta: { summary: summary } }
  end

  def stored_post
    CamaleonCms::Post.find(published_post.id)
  end

  def rejection(key)
    "meta[summary] #{I18n.t("camaleon_cms.admin.post.message.#{key}")}"
  end

  describe 'an editor without the unfiltered-content permission' do
    before { sign_in_as(editor, site: current_site) }

    it 'is refused a summary with a script, and the listing renders none' do
      update_summary(script)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape(rejection('content_rejected')))
      expect(stored_post.get_meta('summary')).to be_blank
      expect(stored_post.title).to eq('Published post')

      get '/post'
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML5.parse(response.body).css('script').map(&:text).grep(/summary/)).to be_empty
    end

    it 'is refused an over-size summary with the size message' do
      update_summary('a' * (CamaleonCms::UnsafeMarkup::MAX_GATED_VALUE_BYTES + 1))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ERB::Util.html_escape(rejection('content_too_large')))
      expect(stored_post.get_meta('summary')).to be_blank
    end

    it 'stores a summary within the content allowlist' do
      update_summary('Plain <b>bold</b> summary')

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('summary')).to eq('Plain <b>bold</b> summary')
    end

    it 'is refused the same summary on a draft autosave, which stores nothing' do
      post "/admin/post_type/#{post_type.id}/drafts",
           params: { post_id: published_post.id, post: { title: 'Draft title' }, meta: { summary: script } }

      expect(JSON.parse(response.body)['error']).to include(rejection('content_rejected'))
      expect(post_type.posts.drafts.where(post_parent: published_post.id)).to be_empty
    end
  end

  describe 'an administrator' do
    before { sign_in_as(admin, site: current_site) }

    it 'stores a summary with a script as written' do
      update_summary(script)

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('summary')).to eq(script)
    end
  end
end
