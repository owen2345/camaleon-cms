# frozen_string_literal: true

# set_field_values resolves each slug's field through the record's get_field_groups, which for a post
# type returns its posts' groups and for a user the groups placed on a site whose id equals the user's.
# So a post type's own field lost to a posts' field of the same slug, and a user's field to another
# site's, and the value gate checked the value as that other field's type. The post type, post, draft,
# user and widget assignment saves now resolve slugs in the groups their permit allows.
RSpec.describe 'Security: a custom-field save resolves slugs in the groups its form renders', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.find_by(slug: 'post') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  def register(group, slug, field_key)
    group.add_manual_field({ 'name' => slug.humanize, 'slug' => slug }, { 'field_key' => field_key })
  end

  def payload(field)
    { '0' => { field.slug => { 'id' => field.id.to_s, 'values' => { '0' => 'value' } } } }
  end

  it "stores a post type's value under its own field, not its posts' field of the same slug" do
    register(post_type.add_custom_field_group({ name: 'Posts', slug: 'posts-fields' }, 'Post'), 'subtitle', 'text_box')
    own = register(post_type.add_custom_field_group({ name: 'Own', slug: 'own-fields' }, 'post_type'),
                   'subtitle', 'editor')

    patch "/admin/settings/post_types/#{post_type.id}", params: {
      post_type: { name: post_type.name, slug: post_type.slug }, field_options: payload(own)
    }

    expect(response).to have_http_status(:found)
    expect(post_type.reload.custom_field_values.where(custom_field_slug: 'subtitle').pluck(:custom_field_id))
      .to eq([own.id])
  end

  # Groups share the fields' table and keep their site's id in parent_id, so a group of a site whose id
  # equals one of the resolving groups' ids matches the parent_id lookup too; one sharing the slug and
  # ordered first must not take the value in place of the field.
  it "stores a post type's value under its field, not a same-slug group whose site id equals the field's group id" do
    own_group = post_type.add_custom_field_group({ name: 'Own', slug: 'own-fields' }, 'post_type')
    own = own_group.add_manual_field({ 'name' => 'Subtitle', 'slug' => 'subtitle', 'field_order' => 1 },
                                     { 'field_key' => 'editor' })
    CamaleonCms::CustomFieldGroup.create!(name: 'Subtitle', slug: 'subtitle', object_class: 'Site',
                                          objectid: 0, parent_id: own_group.id, field_order: 0)

    patch "/admin/settings/post_types/#{post_type.id}", params: {
      post_type: { name: post_type.name, slug: post_type.slug }, field_options: payload(own)
    }

    expect(response).to have_http_status(:found)
    expect(post_type.reload.custom_field_values.where(custom_field_slug: 'subtitle').pluck(:custom_field_id))
      .to eq([own.id])
  end

  it "stores a category's value under its field, not a same-slug group whose site id equals the field's group id" do
    group = post_type.add_custom_field_group({ name: 'Cats', slug: 'cat-fields' }, 'Category')
    own = group.add_manual_field({ 'name' => 'Tagline', 'slug' => 'tagline', 'field_order' => 1 },
                                 { 'field_key' => 'editor' })
    CamaleonCms::CustomFieldGroup.create!(name: 'Tagline', slug: 'tagline', object_class: 'Site',
                                          objectid: 0, parent_id: group.id, field_order: 0)

    post "/admin/post_type/#{post_type.id}/categories", params: {
      category: { name: 'Lookup cat', slug: 'lookup-cat' }, field_options: payload(own)
    }

    category = post_type.categories.find_by!(slug: 'lookup-cat')
    expect(category.custom_field_values.where(custom_field_slug: 'tagline').pluck(:custom_field_id)).to eq([own.id])
  end

  # A post's get_field_groups also holds the groups placed on the post itself, where a same-slug field
  # ordered first won the lookup over the post type's field the permit allowed.
  describe "a post's value lands under its post type's field, not a same-slug field of the post's own group" do
    let(:admin_post) { create(:post, post_type: post_type, owner: admin, slug: 'lookup-post', status: 'published') }
    let(:draft) do
      post_type.posts.create!(title: 'Draft', slug: 'lookup-draft', user_id: admin.id, status: 'draft_child',
                              post_parent: admin_post.id)
    end

    # The decoy is ordered first, so the post's own lookup finds it before the post type's field.
    def register_both(record)
      record.add_custom_field_group({ name: 'Own', slug: 'post-own-fields' })
            .add_manual_field({ 'name' => 'Summary', 'slug' => 'summary', 'field_order' => 0 },
                              { 'field_key' => 'text_box' })
      post_type.add_field({ 'name' => 'Summary', 'slug' => 'summary', 'field_order' => 1 }, { 'field_key' => 'editor' })
    end

    it 'on a post save' do
      own = register_both(admin_post)

      patch "/admin/post_type/#{post_type.id}/posts/#{admin_post.id}", params: {
        post: { title: 'Lookup post', content: 'body', status: 'published' }, field_options: payload(own)
      }

      expect(response).to have_http_status(:found)
      expect(admin_post.reload.custom_field_values.where(custom_field_slug: 'summary').pluck(:custom_field_id))
        .to eq([own.id])
    end

    it 'on a draft save' do
      own = register_both(draft)

      patch "/admin/post_type/#{post_type.id}/drafts/#{draft.id}", params: {
        post: { title: 'Draft' }, field_options: payload(own)
      }

      expect(draft.reload.custom_field_values.where(custom_field_slug: 'summary').pluck(:custom_field_id))
        .to eq([own.id])
    end
  end

  it "stores a user's value under this site's field, not the one of a site sharing the user's id" do
    other_site = CamaleonCms::Site.create!(id: 90_001, name: 'Other Site', slug: 'other-site', taxonomy: 'site')
    member = create(:user, id: other_site.id, role: 'client', site: current_site)
    register(other_site.custom_field_groups.create!(name: 'Other', slug: '_other-user', object_class: 'User',
                                                    objectid: other_site.id), 'bio', 'text_box')
    own = register(current_site.custom_field_groups.create!(name: 'Own', slug: '_own-user', object_class: 'User',
                                                            objectid: current_site.id), 'bio', 'editor')

    patch "/admin/users/#{member.id}", params: {
      user: { username: member.username, email: member.email }, field_options: payload(own)
    }

    expect(response).to have_http_status(:found)
    expect(member.reload.custom_field_values.where(custom_field_slug: 'bio').pluck(:custom_field_id)).to eq([own.id])
  end
end
