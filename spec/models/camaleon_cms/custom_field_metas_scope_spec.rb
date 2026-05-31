# frozen_string_literal: true

require 'rails_helper'

# Regression: meta rows are keyed by both `objectid` and `object_class`. When a CustomField's
# numeric id collides with another model's id (e.g. a Post), an unscoped `metas` association
# leaks the other model's metas, so `get_option('field_key')` returns the wrong value and the
# TinyMCE editor field renders as a plain text_box on the Theme settings page.
RSpec.describe CamaleonCms::CustomField, type: :model do
  describe '#metas scoping by object_class' do
    let(:field) do
      described_class.create!(name: 'Footer message', slug: 'footer', object_class: '_fields')
    end

    before do
      field.set_meta('_default', { field_key: 'editor', default_value: 'hello' })
      # Stray meta belonging to a *different* model that happens to share the same numeric id.
      CamaleonCms::Meta.create!(objectid: field.id, object_class: 'Post', key: '_default',
                                value: { has_category: true }.to_json)
    end

    it 'only reads metas that belong to the CustomField' do
      reloaded = described_class.find(field.id)
      expect(reloaded.metas.pluck(:object_class).uniq).to eq(['CustomField'])
    end

    it 'resolves field_key from its own _default meta' do
      reloaded = described_class.find(field.id)
      expect(reloaded.get_option('field_key')).to eq('editor')
      expect(reloaded.options[:field_key]).to eq('editor')
    end
  end
end
