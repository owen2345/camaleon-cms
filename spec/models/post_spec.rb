# frozen_string_literal: true

require 'rails_helper'
RSpec.describe CamaleonCms::Post do
  describe '#get_field_groups' do
    it 'returns the field groups assigned to current post' do
      post = create(:post)
      group = post.add_custom_field_group(name: 'Sample Group')
      expect(post.get_field_groups).to include(group)
    end

    it 'returns the field groups assigned to the post-type for posts' do
      post = create(:post)
      group = post.post_type.add_custom_field_group(name: 'Sample Group')
      expect(post.get_field_groups).to include(group)
    end
  end

  describe '#add_custom_field_group' do
    it 'adds the field group to the post' do
      post = create(:post)
      group = post.add_custom_field_group(name: 'Sample group')
      expect(post.get_field_groups).to include(group)
    end
  end
end
