# frozen_string_literal: true

# H8: `parent_id` doubles as the tenancy foreign key on taxonomies. For a post type it *is* `site_id`
# (`alias_attribute :site_id, :parent_id`); for a category it is the parent category or the owning
# post type; for a post tag it is the owning post type. It was mass-assignable on the term `update`
# permits, so a manager of one site could re-home a post type (with all its posts, categories, tags
# and field groups) onto another site's domain, or move a category/tag under another site's post type.
RSpec.describe 'Cross-site taxonomy reparenting', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Victim Site', slug: 'victim-site', taxonomy: 'site') }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    # Isolate the term controllers from plugin lifecycle hooks (updated_post_type / updated_category),
    # whose handlers expect form params this minimal request omits. The fix is in the controllers'
    # own param handling, not the hooks.
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:hooks_run)
    sign_in_as(admin, site: current_site)
  end

  describe 'a post type, whose parent_id is its site_id' do
    let!(:articles) { current_site.post_types.create!(name: 'Articles', slug: 'articles') }

    it "ignores a submitted parent_id and keeps the post type on the manager's own site" do
      patch "/admin/settings/post_types/#{articles.id}", params: {
        post_type: { name: 'Articles', slug: 'articles', parent_id: other_site.id }
      }

      expect(articles.reload.site_id).to eq(current_site.id)
    end
  end

  describe 'a category, whose parent_id places it in a post type hierarchy' do
    let!(:category) { post_type.categories.create!(name: 'Cat A', slug: 'cat-a') }
    let!(:victim_post_type) { other_site.post_types.create!(name: 'Victim PT', slug: 'victim-pt') }

    it "refuses to reparent it under another site's post type" do
      patch "/admin/post_type/#{post_type.id}/categories/#{category.id}", params: {
        category: { name: 'Cat A', slug: 'cat-a', parent_id: victim_post_type.id }
      }

      expect(category.reload.parent_id).to eq(post_type.id)
      expect(category.reload.site_id).to eq(current_site.id)
    end

    it "refuses to reparent it under another site's category" do
      victim_category = victim_post_type.categories.create!(name: 'Victim Cat', slug: 'victim-cat')

      patch "/admin/post_type/#{post_type.id}/categories/#{category.id}", params: {
        category: { name: 'Cat A', slug: 'cat-a', parent_id: victim_category.id }
      }

      expect(category.reload.parent_id).to eq(post_type.id)
    end

    it 'still allows reparenting under a category of the same post type' do
      sibling = post_type.categories.create!(name: 'Parent Cat', slug: 'parent-cat')

      patch "/admin/post_type/#{post_type.id}/categories/#{category.id}", params: {
        category: { name: 'Cat A', slug: 'cat-a', parent_id: sibling.id }
      }

      expect(category.reload.parent_id).to eq(sibling.id)
    end
  end

  describe 'a post tag, whose parent_id is its owning post type' do
    let!(:tag) { post_type.post_tags.create!(name: 'Tag A', slug: 'tag-a') }
    let!(:victim_post_type) { other_site.post_types.create!(name: 'Victim PT2', slug: 'victim-pt2') }

    it 'ignores a submitted parent_id and keeps the tag under its own post type' do
      patch "/admin/post_type/#{post_type.id}/post_tags/#{tag.id}", params: {
        post_tag: { name: 'Tag A', slug: 'tag-a', parent_id: victim_post_type.id }
      }

      expect(tag.reload.parent_id).to eq(post_type.id)
    end
  end
end
