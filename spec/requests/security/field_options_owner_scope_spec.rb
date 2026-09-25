# frozen_string_literal: true

# Security: the custom-field allow-list every admin save shares permitted the slug of any field under
# any group placed with the save's object_class, whatever record the group was placed on and whatever
# site owns it. So a post type save accepted slugs registered on every other post type, the site,
# theme and user saves accepted slugs registered by another site, and a widget assignment save
# accepted another widget's slugs; set_field_values then stored the row under the client-supplied
# field id. Each save now permits only the slugs of the groups its form renders for the record: a
# slug registered on the record still saves, a slug registered only on a sibling is dropped.
RSpec.describe 'Security: custom-field saves are confined to the record being saved', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:other_post_type) { current_site.post_types.create!(name: 'Other type', slug: 'other-type') }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Other Site', slug: 'other-site', taxonomy: 'site') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  def register(group, slug)
    group.add_manual_field({ 'name' => slug.humanize, 'slug' => slug }, { 'field_key' => 'text_box' })
  end

  # The payload the admin form submits, carrying the record's own field and a sibling's; the sibling
  # entry names its real field id, so before the fix the row saved under it.
  def field_options(own_field, sibling_field)
    { '0' => {
      own_field.slug => { 'id' => own_field.id.to_s, 'values' => { '0' => 'own value' } },
      sibling_field.slug => { 'id' => sibling_field.id.to_s, 'values' => { '0' => 'sibling value' } }
    } }
  end

  def expect_only_own(record, own_field, sibling_field)
    expect(record.get_field_value(own_field.slug)).to eq('own value')
    expect(record.custom_field_values.where(custom_field_slug: sibling_field.slug)).not_to exist
  end

  it "drops a sibling post type's slug from a post type save" do
    own = register(post_type.add_custom_field_group({ name: 'Own', slug: 'own-pt' }, 'post_type'), 'own_pt')
    sibling = register(other_post_type.add_custom_field_group({ name: 'Other', slug: 'other-pt' }, 'post_type'),
                       'sibling_pt')

    patch "/admin/settings/post_types/#{post_type.id}", params: {
      post_type: { name: post_type.name, slug: post_type.slug }, field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(post_type.reload, own, sibling)
  end

  it "drops a sibling post type's slug from a post save" do
    own = post_type.add_field({ 'name' => 'Own', 'slug' => 'own_post' }, { 'field_key' => 'text_box' })
    sibling = other_post_type.add_field({ 'name' => 'Other', 'slug' => 'sibling_post' }, { 'field_key' => 'text_box' })
    record = create(:post, post_type: post_type, owner: admin, slug: 'own-scope-post', status: 'published')

    patch "/admin/post_type/#{post_type.id}/posts/#{record.id}", params: {
      post: { title: 'Own scope post', content: 'body', status: 'published' },
      field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(record.reload, own, sibling)
  end

  it "drops a sibling post type's slug from a draft save" do
    own = post_type.add_field({ 'name' => 'Own', 'slug' => 'own_draft' }, { 'field_key' => 'text_box' })
    sibling = other_post_type.add_field({ 'name' => 'Other', 'slug' => 'sibling_draft' }, { 'field_key' => 'text_box' })
    parent = create(:post, post_type: post_type, owner: admin, slug: 'own-scope-parent', status: 'published')

    post "/admin/post_type/#{post_type.id}/drafts", params: {
      post_id: parent.id, post: { title: 'Draft' }, field_options: field_options(own, sibling)
    }

    draft = post_type.posts.drafts.where(user_id: admin.id, post_parent: parent.id).order(:id).last
    expect(draft).to be_present
    expect_only_own(draft, own, sibling)
  end

  it "drops a sibling post type's slug from a category save" do
    own = register(post_type.add_custom_field_group({ name: 'Own', slug: 'own-cat' }, 'Category'), 'own_cat')
    sibling = register(other_post_type.add_custom_field_group({ name: 'Other', slug: 'other-cat' }, 'Category'),
                       'sibling_cat')

    post "/admin/post_type/#{post_type.id}/categories", params: {
      category: { name: 'Own scope', slug: 'own-scope-category' }, field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(post_type.categories.find_by!(slug: 'own-scope-category'), own, sibling)
  end

  it "drops a sibling post type's slug from a post tag save" do
    own = register(post_type.add_custom_field_group({ name: 'Own', slug: 'own-tag' }, 'PostTag'), 'own_tag')
    sibling = register(other_post_type.add_custom_field_group({ name: 'Other', slug: 'other-tag' }, 'PostTag'),
                       'sibling_tag')

    post "/admin/post_type/#{post_type.id}/post_tags", params: {
      post_tag: { name: 'Own scope', slug: 'own-scope-tag' }, field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(post_type.post_tags.find_by!(slug: 'own-scope-tag'), own, sibling)
  end

  it "drops another site's slug from the site settings save" do
    own = register(current_site.custom_field_groups.create!(name: 'Own', slug: '_own-site', object_class: 'Site',
                                                            objectid: current_site.id), 'own_site')
    sibling = register(other_site.custom_field_groups.create!(name: 'Other', slug: '_other-site', object_class: 'Site',
                                                              objectid: other_site.id), 'sibling_site')

    patch '/admin/settings/site_saved', params: {
      site: { name: current_site.name, slug: current_site.slug }, field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(CamaleonCms::Site.find(current_site.id), own, sibling)
  end

  it "drops another site's slug from the theme settings save" do
    theme = current_site.get_theme
    own = register(theme.add_field_group({ name: 'Own', slug: '_own-theme' }), 'own_theme')
    sibling = register(other_site.get_theme.add_field_group({ name: 'Other', slug: '_other-theme' }), 'sibling_theme')

    post '/admin/settings/save_theme', params: { field_options: field_options(own, sibling) }

    expect(response).to have_http_status(:found)
    expect_only_own(theme.reload, own, sibling)
  end

  it "drops another site's slug from the user save" do
    own = register(current_site.custom_field_groups.create!(name: 'Own', slug: '_own-user', object_class: 'User',
                                                            objectid: current_site.id), 'own_user')
    sibling = register(other_site.custom_field_groups.create!(name: 'Other', slug: '_other-user', object_class: 'User',
                                                              objectid: other_site.id), 'sibling_user')
    member = create(:user, role: 'client', site: current_site)

    patch "/admin/users/#{member.id}", params: {
      user: { username: member.username, email: member.email }, field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(member.reload, own, sibling)
  end

  it "drops another widget's slug from a widget assignment save" do
    widget = current_site.widgets.create!(name: 'Own widget', slug: 'own-widget')
    other_widget = current_site.widgets.create!(name: 'Other widget', slug: 'other-widget')
    own = register(widget.add_custom_field_group(name: 'Own', slug: 'own-widget-fields'), 'own_widget')
    sibling = register(other_widget.add_custom_field_group(name: 'Other', slug: 'other-widget-fields'),
                       'sibling_widget')
    sidebar = current_site.sidebars.create!(name: 'Own sidebar', slug: 'own-sidebar')
    assigned = sidebar.assigned.create!(title: 'Default', widget_id: widget.id)

    patch "/admin/appearances/widgets/sidebar/#{sidebar.id}/assign/#{assigned.id}", params: {
      assign: { title: 'Default' }, field_options: field_options(own, sibling)
    }

    expect(response).to have_http_status(:found)
    expect_only_own(assigned.reload, own, sibling)
  end
end
