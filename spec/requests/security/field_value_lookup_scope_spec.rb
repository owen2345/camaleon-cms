# frozen_string_literal: true

# set_field_values resolves each slug's field through the record's get_field_groups, which for a post
# type returns its posts' groups and for a user the groups placed on a site whose id equals the user's.
# So a post type's own field lost to a posts' field of the same slug, and a user's field to another
# site's, and the value gate checked the value as that other field's type. The post type, user and
# widget assignment saves now resolve slugs in the groups their form renders.
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
