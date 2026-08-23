# frozen_string_literal: true

# Security (audit): cama_permitted_field_options resolved the payload with `params.require` and then
# called `#keys`/`#permit` on it, so a non-hash `field_options` (a scalar `field_options=foo`, or an
# array) raised NoMethodError -> 500. Every set_field_values caller shares the helper, so the same
# malformed-request crash was reachable through each of them; the drafts endpoint stands in for all.
# The helper now treats a non-hash payload as empty and saves normally.
RSpec.describe 'Security: non-hash field_options is ignored, not a 500', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:parent_post) do
    post_type.posts.create!(title: 'Parent', slug: 'parent', user_id: admin.id, status: 'published')
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    # A registered field makes the allow-list non-blank, so the helper reaches the #keys/#permit path
    # the scalar param used to crash on (an empty allow-list short-circuits to {} before that line).
    post_type.add_field({ 'name' => 'Subtitle', 'slug' => 'subtitle' }, { 'field_key' => 'text_box' })
    sign_in_as(admin, site: current_site)
  end

  it 'saves the draft and writes no field values when field_options is a scalar' do
    post "/admin/post_type/#{post_type.id}/drafts", params: {
      post_id: parent_post.id,
      post: { title: 'Draft with scalar field_options' },
      field_options: 'foo'
    }

    expect(response).to have_http_status(:ok)
    draft = post_type.posts.drafts.where(user_id: admin.id, post_parent: parent_post.id).order(:id).last
    expect(draft).to be_present
    expect(draft.custom_field_values).to be_empty
  end

  it 'saves the draft when field_options is an array' do
    post "/admin/post_type/#{post_type.id}/drafts", params: {
      post_id: parent_post.id,
      post: { title: 'Draft with array field_options' },
      field_options: %w[a b]
    }

    expect(response).to have_http_status(:ok)
  end
end
