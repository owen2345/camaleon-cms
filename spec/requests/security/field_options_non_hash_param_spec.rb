# frozen_string_literal: true

# Security (audit): cama_permitted_field_options resolved the payload with `params.require` and then
# called `#keys`/`#permit` on it, so a non-hash `field_options` (a scalar `field_options=foo`, or an
# array) raised NoMethodError -> 500. Every set_field_values caller shares the helper, so the same
# malformed-request crash was reachable through each of them; the category save stands in for them.
# The helper treats a non-hash payload as empty and the save proceeds. The post save and the draft
# save are the exception: they refuse a malformed `field_options` up front, like `meta` and `options`
# (see meta_container_refusal_spec.rb).
RSpec.describe 'Security: non-hash field_options is ignored, not a 500', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    # A registered field makes the allow-list non-blank, so the helper reaches the #keys/#permit path
    # the scalar param used to crash on (an empty allow-list short-circuits to {} before that line).
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Category fields', slug: 'category-fields',
                                                  object_class: 'PostType_Category', objectid: post_type.id,
                                                  site: current_site)
    group.add_manual_field({ 'name' => 'Subtitle', 'slug' => 'subtitle' }, { 'field_key' => 'text_box' })
    sign_in_as(admin, site: current_site)
  end

  it 'saves the category and writes no field values when field_options is a scalar' do
    post "/admin/post_type/#{post_type.id}/categories", params: {
      category: { name: 'Scalar fields', slug: 'scalar-fields' },
      field_options: 'foo'
    }

    expect(response).to have_http_status(:found)
    category = post_type.categories.find_by(slug: 'scalar-fields')
    expect(category).to be_present
    expect(category.custom_field_values).to be_empty
  end

  it 'saves the category when field_options is an array' do
    post "/admin/post_type/#{post_type.id}/categories", params: {
      category: { name: 'Array fields', slug: 'array-fields' },
      field_options: %w[a b]
    }

    expect(response).to have_http_status(:found)
    expect(post_type.categories.find_by(slug: 'array-fields')).to be_present
  end

  it 'refuses a draft save whose field_options is a scalar, storing nothing' do
    parent_post = create(:post, post_type: post_type, owner: admin, slug: 'container-parent', status: 'published')

    post "/admin/post_type/#{post_type.id}/drafts", params: {
      post_id: parent_post.id,
      post: { title: 'Draft with scalar field_options' },
      field_options: 'foo'
    }

    expect(JSON.parse(response.body)['error'])
      .to include(I18n.t('camaleon_cms.admin.post.message.malformed_group', group: 'field_options'))
    expect(post_type.posts.drafts.where(post_parent: parent_post.id)).to be_empty
  end
end
