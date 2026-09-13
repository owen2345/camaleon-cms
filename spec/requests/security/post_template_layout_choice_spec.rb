# frozen_string_literal: true

# The post editor offers only the current theme's post templates and layouts (plus what the
# `post_get_list_templates` / `post_get_list_layouts` hooks add), but the save stored whatever name
# `meta[template]`, `meta[layout]`, `options[default_template]` or `options[default_layout]` carried.
# The public page renders any template the view lookup finds, so a non-admin could point a post at an
# admin view -- a 500 on every visit -- or dress the public page in the admin layout.
RSpec.describe 'Security: post template and layout choices', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:editor) { create(:user, role: 'editor', site: current_site) }
  let(:contributor) { create(:user, role: 'contributor', site: current_site) }
  let(:admin_view) { 'camaleon_cms/admin/settings/site' }
  let!(:published_post) do
    create(:post, post_type: post_type, owner: admin, title: 'Published post', slug: 'published-post',
                  status: 'published')
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def refusal(field)
    I18n.t('camaleon_cms.admin.post.message.value_not_offered', field: field)
  end

  def update_published_post(meta: {}, options: {})
    patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
          params: { post: { title: 'Changed title', content: 'body', status: 'published' },
                    meta: meta, options: options }
  end

  def stored_post
    CamaleonCms::Post.find(published_post.id)
  end

  describe 'a non-admin' do
    before { sign_in_as(editor, site: current_site) }

    it 'cannot name a template the editor does not offer' do
      update_published_post(meta: { template: admin_view })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(refusal('meta[template]'))
      expect(stored_post.get_meta('template')).to be_blank
      expect(stored_post.title).to eq('Published post')

      get '/published-post'
      expect(response).to have_http_status(:ok)
    end

    it 'cannot name a layout the editor does not offer' do
      update_published_post(meta: { layout: 'camaleon_cms/admin' })

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(refusal('meta[layout]'))
      expect(stored_post.get_meta('layout')).to be_blank
    end

    it 'saves an offered layout, a blank template and a template a plugin hook offers' do
      hook = ->(args) { args[:tempates] << 'template_from_plugin' }
      PluginRoutes.add_anonymous_hook('post_get_list_templates', hook, 'template_choice_spec')

      update_published_post(meta: { template: 'template_from_plugin', layout: 'index' })

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('template')).to eq('template_from_plugin')
      expect(stored_post.get_meta('layout')).to eq('index')
    ensure
      PluginRoutes.remove_anonymous_hook('post_get_list_templates', 'template_choice_spec')
    end

    it 'saves a template a plugin hook offers as a [label, value] pair' do
      hook = ->(args) { args[:tempates] << ['Landing page', 'template_landing'] }
      PluginRoutes.add_anonymous_hook('post_get_list_templates', hook, 'template_choice_spec')

      update_published_post(meta: { template: 'template_landing' })

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('template')).to eq('template_landing')
    ensure
      PluginRoutes.remove_anonymous_hook('post_get_list_templates', 'template_choice_spec')
    end

    it 'saves a blank template and layout' do
      update_published_post(meta: { template: '', layout: '' })

      expect(response).to have_http_status(:found)
      expect(stored_post.title).to eq('Changed title')
    end

    it 'cannot autosave a draft naming a template the editor does not offer' do
      post "/admin/post_type/#{post_type.id}/drafts",
           params: { post_id: published_post.id, post: { title: 'Draft title' }, meta: { template: admin_view } }

      expect(JSON.parse(response.body)['error']).to include(refusal('meta[template]'))
      expect(post_type.posts.drafts.where(post_parent: published_post.id)).to be_empty
    end
  end

  describe 'a contributor' do
    before { sign_in_as(contributor, site: current_site) }

    it 'cannot set a default template the editor does not offer' do
      post "/admin/post_type/#{post_type.id}/posts",
           params: { post: { title: 'Contributor post', slug: 'contributor-post', content: 'body' },
                     options: { default_template: admin_view } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(refusal('options[default_template]'))
      expect(post_type.posts.find_by(slug: 'contributor-post')).to be_nil
    end

    it 'cannot set a default layout the editor does not offer' do
      post "/admin/post_type/#{post_type.id}/posts",
           params: { post: { title: 'Contributor post', slug: 'contributor-post', content: 'body' },
                     options: { default_layout: 'camaleon_cms/admin' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(refusal('options[default_layout]'))
      expect(post_type.posts.find_by(slug: 'contributor-post')).to be_nil
    end
  end

  # The refusal is decided before the create_post/update_post hooks, so a hook that writes to the
  # persisted post cannot land before the save is refused.
  describe 'a hook that writes on save' do
    before { sign_in_as(editor, site: current_site) }

    it 'runs only for an accepted save' do
      hook = ->(args) { args[:post].set_option('hooked', 'yes') }
      PluginRoutes.add_anonymous_hook('update_post', hook, 'template_choice_spec')

      update_published_post(meta: { template: admin_view })
      expect(response).to have_http_status(:ok)
      expect(stored_post.get_option('hooked')).to be_blank

      update_published_post(meta: { template: '' })
      expect(response).to have_http_status(:found)
      expect(stored_post.get_option('hooked')).to eq('yes')
    ensure
      PluginRoutes.remove_anonymous_hook('update_post', 'template_choice_spec')
    end
  end

  # A refused update re-renders the form on the authorization the request already passed; it does not
  # re-authorize the post after the submitted attributes were assigned to it, which sent a user whose
  # right rests on the post being published (edit_publish) to the dashboard as unauthorized.
  describe 'a user whose update right rests on the post being published' do
    let(:role) { current_site.user_roles.create!(name: 'Publish reviewer', slug: 'publish-reviewer-choice') }
    let(:reviewer) { create(:user, role: role.slug, site: current_site) }

    before do
      role.set_meta("_manager_#{current_site.id}", {})
      role.set_meta("_post_type_#{current_site.id}", { 'edit_publish' => [post_type.id], 'publish' => [post_type.id] })
      sign_in_as(reviewer, site: current_site)
    end

    it 'sees the refusal when also changing the status' do
      patch "/admin/post_type/#{post_type.id}/posts/#{published_post.id}",
            params: { post: { title: 'Changed title', content: 'body', status: 'pending' },
                      meta: { template: admin_view } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(refusal('meta[template]'))
      expect(stored_post.status).to eq('published')
      expect(stored_post.title).to eq('Published post')
    end
  end

  describe 'an administrator' do
    before { sign_in_as(admin, site: current_site) }

    it 'may name a template the editor does not offer' do
      update_published_post(meta: { template: 'template_not_in_the_theme' })

      expect(response).to have_http_status(:found)
      expect(stored_post.get_meta('template')).to eq('template_not_in_the_theme')
    end
  end
end
