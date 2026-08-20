# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M17, scan-and-reject policy): an `editor` custom-field value reaches
# the frontend verbatim, so the admin save path must refuse -- not rewrite -- a value an untrusted
# author is not permitted to write. This drives the real posts controller as a non-admin role with
# edit rights but without post_content_unfiltered_html.
RSpec.describe 'Security: custom-field value rejection (M17)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.find_by(slug: 'post') }
  let(:editor_user) do
    create(:user, role: 'editor', site: current_site, password: 'longenough1', password_confirmation: 'longenough1')
  end
  let(:script) { '<p>keep</p><script>alert(1)</script>' }

  before do
    current_site.user_roles.find_by(slug: 'editor')
                .set_meta("_post_type_#{current_site.id}", edit: [post_type.id], create: [post_type.id])
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Extra', slug: 'extra',
                                                  object_class: 'PostType_Post', objectid: post_type.id,
                                                  site: current_site.model)
    @field = group.add_manual_field({ name: 'Body', slug: 'extra_body' }, { field_key: 'editor' })
    sign_in_as(editor_user, site: current_site)
  end

  def update_post_with_field_value(post, value)
    patch "/admin/post_type/#{post_type.id}/posts/#{post.id}", params: {
      post: { title: post.title, content: '<p>plain</p>', status: 'published' },
      field_options: { '0' => { 'extra_body' => { 'id' => @field.id.to_s, 'values' => { '0' => value } } } }
    }
  end

  it 'refuses to store a script editor value for an untrusted author' do
    post_record = create(:post, post_type: post_type, owner: editor_user)

    update_post_with_field_value(post_record, script)

    expect(flash[:error]).to include('not allowed')
    expect(post_record.get_field_value('extra_body')).to be_blank
  end

  it 'stores legitimate rich text through the same path' do
    post_record = create(:post, post_type: post_type, owner: editor_user)

    update_post_with_field_value(post_record, '<p>hello <strong>world</strong></p>')

    expect(post_record.get_field_value('extra_body')).to eq('<p>hello <strong>world</strong></p>')
  end
end
