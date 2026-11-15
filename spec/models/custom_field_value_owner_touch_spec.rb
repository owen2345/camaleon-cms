# frozen_string_literal: true

# The save of a custom-field value touches its owner, the record that `owner` gives.
RSpec.describe CamaleonCms::CustomFieldsRelationship, type: :model do
  let(:site) { create(:site) }
  let(:widget) { site.widgets.create!(name: 'Touch widget', slug: 'touch-widget') }
  let(:field) do
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields', object_class: 'Main',
                                                  objectid: widget.id, site: site)
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
  end

  def save_value(owner_record, object_class)
    described_class.create!(objectid: owner_record.id, object_class: object_class, custom_field_id: field.id,
                            custom_field_slug: 'note', value: 'value')
  end

  it 'touches the widget of a widget value' do
    widget.update_column(:updated_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

    save_value(widget, 'Main')

    expect(widget.reload.updated_at).to be > 1.hour.ago
  end

  it 'touches the post of a post value' do
    post = create(:post)
    post.update_column(:updated_at, 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

    save_value(post, 'Post')

    expect(post.reload.updated_at).to be > 1.hour.ago
  end
end
