# frozen_string_literal: true

require 'rails_helper'
RSpec.describe CamaleonCms::Category do
  let(:site) { create(:site).decorate }

  describe '#path' do
    it 'returns the parents path category' do
      parent = create(:category, :with_parent)
      category = create(:category, parent: parent)
      expect(category.path).to eq([parent.parent, parent, category])
    end
  end

  describe '#post_type' do
    describe 'when child category' do
      let(:category) { create(:category, :with_parent) }

      it 'looks for the root category and returns the its post-type' do
        expect(category.post_type).to eq(category.parent.post_type)
      end

      it 'returns a post_type model' do
        expect(category.post_type).to be_a(CamaleonCms::PostType)
      end
    end

    describe 'when root category' do
      it 'returns the associated post-type' do
        category = create(:category)
        expect(category.post_type).to be_a(CamaleonCms::PostType)
      end
    end
  end

  describe '#get_field_groups' do
    it 'returns the field groups assigned to the post-type for categories' do
      category = create(:category)
      post_type = category.post_type
      group = post_type.add_custom_field_group({ name: 'Sample Group' }, 'Category')
      expect(category.get_field_groups).to include(group)
    end
  end
end
