# frozen_string_literal: true

require 'rails_helper'
RSpec.describe CamaleonCms::PostType do
  describe '#get_field_groups' do
    let(:post_type) { create(:post_type) }

    describe 'when fetching groups for categories form under current post-type' do
      let(:kind) { 'Category' }
      let!(:group) { post_type.add_custom_field_group({ name: 'Sample Group' }, kind) }

      it 'returns the assigned custom-field-groups' do
        expect(post_type.get_field_groups(kind)).to include(group)
      end

      it 'includes the group in the corresponding model' do
        category = create(:category, post_type: post_type)
        expect(category.get_field_groups).to include(group)
      end
    end

    describe 'when fetching groups for posts form under current post-type' do
      let(:kind) { 'Post' }
      let!(:group) { post_type.add_custom_field_group({ name: 'Sample Group' }, kind) }

      it 'returns the assigned custom-field-groups' do
        expect(post_type.get_field_groups(kind)).to include(group)
      end

      it 'includes the group in the corresponding model' do
        post = create(:post, post_type: post_type)
        expect(post.get_field_groups).to include(group)
      end
    end

    describe 'when fetching groups for post_tags form under current post-type' do
      let(:kind) { 'PostTag' }
      let!(:group) { post_type.add_custom_field_group({ name: 'Sample Group' }, kind) }

      it 'returns the assigned custom-field-groups' do
        expect(post_type.get_field_groups(kind)).to include(group)
      end

      it 'includes the group in the corresponding model' do
        tag = create(:post_tag, post_type: post_type)
        expect(tag.get_field_groups).to include(group)
      end
    end

    describe 'when fetching groups current post-type form' do
      let(:kind) { 'self' }
      let!(:group) { post_type.add_custom_field_group({ name: 'Sample Group' }, kind) }

      it 'returns the assigned custom-field-groups' do
        expect(post_type.get_field_groups(kind)).to include(group)
      end
    end
  end

  describe '#add_custom_field_group' do
    let(:post_type) { create(:post_type) }
    let(:kind) { 'Post' }

    it 'creates the corresponding fields group for posts form' do
      group = post_type.add_custom_field_group({ name: 'test' }, kind)
      expect( post_type.get_field_groups(kind)).to include(group)
    end
  end

  describe '#default_custom_field_group' do
    let(:post_type) { create(:post_type) }
    let(:kind) { 'Post' }

    it 'creates a default group when not existed yet' do
      qty = post_type.get_field_groups(kind).count
      post_type.default_custom_field_group(kind)
      expect(post_type.get_field_groups(kind).count).to eq(qty + 1)
    end

    it 'returns the existent default group' do
      group = post_type.default_custom_field_group(kind)
      expect(post_type.default_custom_field_group(kind)).to eq(group)
    end
  end

  describe '#add_field' do
    let(:post_type) { create(:post_type) }
    let(:kind) { 'Post' }

    it 'adds the custom field to the default group for posts form' do
      data_field = build(:custom_field)
      field = post_type.add_field(data_field.as_json(only: %i[slug name description]), data_field.settings)
      expect(post_type.get_field_object(data_field.slug)).to eq(field)
    end
  end
end
