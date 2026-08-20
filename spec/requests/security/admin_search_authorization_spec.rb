# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M12): two admin endpoints ran with no authorization.
#   * AdminController#search queried current_site.posts with no status filter and no permission check,
#     so any admin-area user (e.g. a client) could enumerate every post title/slug in every status.
#   * Posts::DraftsController#index rendered the post type as JSON with no authorize! call.
RSpec.describe 'Security: admin search and drafts authorization', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:client) { create(:user, role: 'client', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first_or_create!(name: 'Post', site: current_site) }
  let!(:unpublished_post) do
    post_type.posts.create!(title: 'SECRETDRAFT title', slug: 'secretdraft', user_id: admin.id, status: 'pending')
  end

  before { allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site) }

  describe 'GET /admin/search (content)' do
    it 'does not expose unpublished content to a user without content permissions' do
      sign_in_as(client, site: current_site)

      get '/admin/search', params: { q: 'secretdraft', kind: 'content' }

      expect(response.body).not_to include(unpublished_post.title)
    end

    it 'still returns matching content to an authorized admin' do
      sign_in_as(admin, site: current_site)

      get '/admin/search', params: { q: 'secretdraft', kind: 'content' }

      expect(response.body).to include(unpublished_post.title)
    end
  end

  describe 'GET /admin/search (category)' do
    # Categories nest: a child category's parent_id is its parent *category*, not a post type. The
    # post-type link every category carries (nested or not) is post_type_id (the status column), so
    # search must scope by that -- scoping by parent_id silently dropped every nested category, even
    # for full admins.
    it 'finds a nested category for an admin' do
      parent = post_type.categories.create!(name: 'Parent Cat', slug: 'parent-cat')
      parent.children.create!(name: 'Nested Child Cat', slug: 'nested-child-cat')

      sign_in_as(admin, site: current_site)

      get '/admin/search', params: { q: 'nested child', kind: 'category' }

      expect(response.body).to include('Nested Child Cat')
    end
  end

  describe 'GET /admin/search with a non-String q param' do
    # ?q[]=x and ?q[a]=b arrive as Array / ActionController::Parameters; neither responds to
    # #downcase, which 500ed the action for any signed-in admin-area user.
    it 'treats an array q as an empty query instead of 500ing' do
      sign_in_as(admin, site: current_site)

      get '/admin/search', params: { q: ['x'], kind: 'content' }

      expect(response).to have_http_status(:ok)
    end

    it 'treats a hash q as an empty query instead of 500ing' do
      sign_in_as(admin, site: current_site)

      get '/admin/search', params: { q: { a: 'b' }, kind: 'content' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /admin/search (category and tag) for a taxonomy-manager role' do
    # Categories and tags are authorized by their own :categories / :post_tags abilities (the roles UI
    # grants manage_categories / manage_tags independently of any post edit right), so a taxonomy
    # manager with no :posts grant anywhere must still find the taxonomies they manage.
    let(:role) { current_site.user_roles.create!(name: 'Taxonomist', slug: 'taxonomist') }
    let(:taxonomist) { create(:user, role: role.slug, site: current_site) }

    before do
      role.set_meta("_post_type_#{current_site.id}",
                    { 'manage_categories' => [post_type.id.to_s], 'manage_tags' => [post_type.id.to_s] })
      sign_in_as(taxonomist, site: current_site)
    end

    it 'returns categories of the post types whose categories they manage' do
      post_type.categories.create!(name: 'Managed Cat', slug: 'managed-cat')

      get '/admin/search', params: { q: 'managed cat', kind: 'category' }

      expect(response.body).to include('Managed Cat')
    end

    it 'returns tags of the post types whose tags they manage' do
      post_type.post_tags.create!(name: 'Managed Tag', slug: 'managed-tag')

      get '/admin/search', params: { q: 'managed tag', kind: 'tag' }

      expect(response.body).to include('Managed Tag')
    end
  end

  describe 'GET /admin/search kind and visibility scoping for a limited role' do
    # Pins the three non-content kind clauses and the own-vs-edit_other OR clause, none of which the
    # admin examples reach (admins short-circuit on can?(:manage, :all)) or the client examples
    # exercise (an empty pt_ids empties the scope before the OR clause matters).
    let(:role) { current_site.user_roles.create!(name: 'Editor P', slug: 'editor-p') }
    let(:editor) { create(:user, role: role.slug, site: current_site) }
    let(:granted_post_type) { create(:post_type, slug: 'granted-pt', name: 'Grantedpt Docs', site: current_site) }
    let(:other_post_type) { create(:post_type, slug: 'unrelated-pt', name: 'Unrelatedpt Docs', site: current_site) }

    before do
      role.set_meta("_post_type_#{current_site.id}", { 'edit' => [granted_post_type.id.to_s] })
      sign_in_as(editor, site: current_site)
    end

    it 'limits post_type results to the post types the caller may list' do
      granted_post_type
      other_post_type

      get '/admin/search', params: { q: 'pt docs', kind: 'post_type' }

      expect(response.body).to include('Grantedpt Docs')
      expect(response.body).not_to include('Unrelatedpt Docs')
    end

    it 'hides categories of post types whose categories the caller does not manage' do
      other_post_type.categories.create!(name: 'Hiddencat Docs', slug: 'hiddencat-docs')

      get '/admin/search', params: { q: 'hiddencat', kind: 'category' }

      expect(response.body).not_to include('Hiddencat Docs')
    end

    it 'hides tags of post types whose tags the caller does not manage' do
      other_post_type.post_tags.create!(name: 'Hiddentag Docs', slug: 'hiddentag-docs')

      get '/admin/search', params: { q: 'hiddentag', kind: 'tag' }

      expect(response.body).not_to include('Hiddentag Docs')
    end

    it "limits content results to the caller's own posts on types without edit_other" do
      granted_post_type.posts.create!(title: 'Ownsecret Report', slug: 'ownsecret',
                                      user_id: editor.id, status: 'pending')
      granted_post_type.posts.create!(title: 'Foreignsecret Report', slug: 'foreignsecret',
                                      user_id: admin.id, status: 'pending')

      get '/admin/search', params: { q: 'secret report', kind: 'content' }

      expect(response.body).to include('Ownsecret Report')
      expect(response.body).not_to include('Foreignsecret Report')
    end

    it "includes other users' posts on types where the caller holds edit_other" do
      role.set_meta("_post_type_#{current_site.id}", { 'edit_other' => [granted_post_type.id.to_s] })
      granted_post_type.posts.create!(title: 'Foreignsecret Report', slug: 'foreignsecret',
                                      user_id: admin.id, status: 'pending')

      get '/admin/search', params: { q: 'foreignsecret', kind: 'content' }

      expect(response.body).to include('Foreignsecret Report')
    end
  end

  describe 'GET /admin/post_type/:post_type_id/drafts (#index)' do
    it 'denies a user without :posts permission on the post type' do
      sign_in_as(client, site: current_site)

      get "/admin/post_type/#{post_type.id}/drafts"

      # CanCan::AccessDenied is rescued into a dashboard redirect, not a JSON render. Assert the
      # target, not just :found -- a broken sign-in also 302s (to the login page), which would let
      # this example pass with authorize! never reached.
      expect(response).to redirect_to(cama_admin_dashboard_path)
    end

    it 'allows an authorized admin' do
      sign_in_as(admin, site: current_site)

      get "/admin/post_type/#{post_type.id}/drafts"

      expect(response).to have_http_status(:ok)
    end
  end
end
