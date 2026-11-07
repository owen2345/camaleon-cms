# frozen_string_literal: true

# A host app can add custom fields to its own model with CommonRelationships and CustomFieldsRead,
# without CamaleonCms::Metas. The custom-field writers then store a value as for a Camaleon model.
RSpec.describe CamaleonCms::CustomFieldsRead do
  let(:post_type) { create(:post_type) }
  let(:group) do
    CamaleonCms::CustomFieldGroup.create!(name: 'Fields', slug: 'fields', object_class: 'PostType_Post',
                                          objectid: post_type.id, site: post_type.site)
  end
  let(:field_id) do
    group.add_manual_field({ name: 'Note', slug: 'note' }, { field_key: 'text_box' })
    CamaleonCms::CustomField.find_by!(parent_id: group.id, slug: 'note').id
  end
  # A model of the host app on the posts table, with no Metas
  let(:record) do
    model = Class.new(CamaleonRecord) do
      self.table_name = CamaleonCms::PostDefault.table_name
      self.inheritance_column = :_type_disabled
    end
    stub_const('HostFieldsRecord', model)
    model.include(CamaleonCms::CommonRelationships)
    model.include(described_class)
    model.find(create(:post, post_type: post_type).id)
  end

  def stored_note
    record.custom_field_values.find_by!(custom_field_slug: 'note').value
  end

  it 'has no Metas' do
    expect(record.class.include?(CamaleonCms::Metas)).to be(false)
  end

  it 'stores a value through set_field_value' do
    record.set_field_value('note', { a: 1 }, field_id: field_id)

    expect(stored_note).to eq('{"a":1}')
  end

  it 'stores a value through set_field_values' do
    field_id
    record.set_field_values({ '0' => { 'note' => { values: { '0' => true } } } },
                            CamaleonCms::CustomFieldGroup.where(id: group.id))

    expect(stored_note).to eq('true')
  end

  it 'stores a value through update_field_value' do
    record.set_field_value('note', 'old', field_id: field_id)

    expect(record.update_field_value('note', [1, 'x'])).to be(true)
    expect(stored_note).to eq('[1,"x"]')
  end
end
