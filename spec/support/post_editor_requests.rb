# frozen_string_literal: true

# The post editor's request specs (spec/requests/security/post_*_spec.rb) share one setup: the shared
# site and its `post` post type, an administrator, an editor and a contributor, a published post owned
# by the administrator, and the update request against it. A spec adds what is its own.
RSpec.shared_context 'with the post editor' do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:admin) { create(:user_admin, site: current_site) }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:contributor) { create(:user, role: 'contributor', site: current_site) }
  let(:admin_view) { 'camaleon_cms/admin/settings/site' }
  let(:published_post) do
    create(:post, post_type: post_type, owner: admin, title: 'Published post', slug: 'published-post',
                  status: 'published')
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def update_published_post(post: {}, meta: {}, options: {})
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: { post: { title: 'Changed title', content: 'body', status: 'published' }.merge(post),
                    meta: meta, options: options }
  end

  def stored_post
    CamaleonCms::Post.find(published_post.id)
  end
end
