# frozen_string_literal: true

RSpec.describe 'Custom field definition lifecycle', type: :model do
  init_site

  let(:site) { Cama::Site.first }
  let(:post_type) { site.post_types.where(slug: 'post').first_or_create!(name: 'Post', site: site) }
  let(:content) { create(:post, post_type: post_type, slug: 'lifecycle-post') }

  # Green at 2.9.2 and on master alike: teardown is owned by
  # CustomFieldsRead#_destroy_custom_field_groups, which runs before any association
  # dependent. Pinned here because dropping the redundant delete_all is only safe
  # while this hook keeps doing the complete job.
  it 'tears down the individual group, field, option metas, and values on post destroy' do
    group = content.add_custom_field_group(name: 'Individual Group', slug: 'individual-group')
    field = group.add_manual_field({ name: 'Color', slug: 'color' }, { field_key: 'text_box' })
    content.custom_field_values.create!(custom_field_id: field.id, custom_field_slug: 'color', value: 'red')

    content.destroy!

    expect(CamaleonCms::CustomFieldGroup.unscoped.exists?(group.id)).to be(false)
    expect(CamaleonCms::CustomField.unscoped.exists?(field.id)).to be(false)
    expect(CamaleonCms::Meta.where(object_class: 'CustomField', objectid: field.id)).to be_empty
    expect(CamaleonCms::CustomFieldsRelationship.where(object_class: 'Post', objectid: content.id)).to be_empty
  end

  it 'reaps placement groups with callbacks on post type destroy' do
    reap_type = create(:post_type, slug: 'reap-pt', site: site)
    group = reap_type.add_custom_field_group({ name: 'PT Fields', slug: 'pt-fields' }, 'Post')
    field = group.add_manual_field({ name: 'Field', slug: 'reap-field' }, { field_key: 'text_box' })

    reap_type.destroy!

    expect(CamaleonCms::CustomFieldGroup.unscoped.exists?(group.id)).to be(false)
    expect(CamaleonCms::CustomField.unscoped.exists?(field.id)).to be(false)
  end

  it 'leaves definitions attached to a hook-less owner when it is destroyed' do
    author = create(:user, site: site)
    comment = content.comments.create!(user_id: author.id, content: 'a comment', approved: 'approved')
    group = CamaleonCms::CustomFieldGroup.create!(
      name: 'Comment Group', slug: 'comment-group',
      object_class: 'PostComment', objectid: comment.id, parent_id: site.id
    )
    field = group.add_manual_field({ name: 'Rating', slug: 'rating' }, { field_key: 'text_box' })

    comment.destroy!

    expect(CamaleonCms::CustomFieldGroup.unscoped.exists?(group.id)).to be(true)
    expect(CamaleonCms::CustomField.unscoped.exists?(field.id)).to be(true)
    expect(CamaleonCms::Meta.where(object_class: 'CustomField', objectid: field.id)).to be_present
  end
end
