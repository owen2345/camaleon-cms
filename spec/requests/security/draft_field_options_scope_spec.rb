# frozen_string_literal: true

# Security (audit 2026-08-11 M8): the drafts controller passed params[:field_options] straight to
# set_field_values, so a caller could write custom_field_values with attacker-chosen slugs, ids and
# group numbers -- keys never registered on the post type. #1235 confined drafts to the caller's own
# per-user buffer, so this is a same-user data-integrity deviation rather than cross-user escalation,
# but the draft path must enforce the same registered-slug allow-list the post and settings
# controllers use (cama_permitted_field_options). An unregistered slug is dropped; a registered one
# still persists.
RSpec.describe 'Security: draft custom-field options are confined to registered slugs (M8)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }
  let(:parent_post) do
    post_type.posts.create!(title: 'Parent', slug: 'parent', user_id: admin.id, status: 'published')
  end

  let(:subtitle_field) { post_type.get_field_object('subtitle') }

  # A registered slug alongside one never registered on the post type (the foreign entry reuses a
  # real field id so the row would save): the permit must keep the registered slug and drop the
  # foreign one.
  let(:field_options) do
    { '0' => {
      'subtitle' => { 'id' => subtitle_field.id, 'values' => { '0' => 'legit subtitle' } },
      'evil_field' => { 'id' => subtitle_field.id, 'values' => { '0' => 'injected' } }
    } }
  end

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    post_type.add_field({ 'name' => 'Subtitle', 'slug' => 'subtitle' }, { 'field_key' => 'text_box' })
    sign_in_as(admin, site: current_site)
  end

  def create_draft_with(field_options)
    post "/admin/post_type/#{post_type.id}/drafts", params: {
      post_id: parent_post.id,
      post: { title: 'Draft with fields' },
      field_options: field_options
    }
    post_type.posts.drafts.where(user_id: admin.id, post_parent: parent_post.id).order(:id).last
  end

  def expect_only_subtitle(draft)
    expect(draft.custom_field_values.where(custom_field_slug: 'subtitle')).to exist
    expect(draft.custom_field_values.where(custom_field_slug: 'evil_field')).not_to exist
  end

  it 'drops a field_options entry whose slug is not registered on the post type' do
    draft = create_draft_with(field_options)

    expect(draft).to be_present
    expect_only_subtitle(draft)
  end

  it 'drops an unregistered slug on update too' do
    draft = post_type.posts.create!(title: 'Draft', slug: 'draft-x', user_id: admin.id,
                                    status: 'draft_child', post_parent: parent_post.id)

    patch "/admin/post_type/#{post_type.id}/drafts/#{draft.id}", params: {
      post: { title: 'Draft' },
      field_options: field_options
    }

    expect_only_subtitle(draft)
  end
end
