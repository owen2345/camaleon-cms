# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::PostType, type: :model do
  it 'persists values for fields added through post type groups' do
    post_type = create(:post_type, data_options: { has_category: false, has_picture: false })

    post_type.add_field(
      { name: 'Pattern', slug: 'pattern' },
      { field_key: 'checkbox' }
    )

    post = post_type.add_post(title: 'Counters', content: 'content', fields: { pattern: true })

    expect(post).to be_present
    expect(post.custom_field_values.where(custom_field_slug: 'pattern')).not_to be_empty
  end

  it 'falls back to post type field lookup when direct group lookup is unavailable' do
    post_type = create(:post_type, data_options: { has_category: false, has_picture: false })
    post_type.add_field({ name: 'Pattern', slug: 'pattern' }, { field_key: 'checkbox' })
    post = create(:post, post_type: post_type)

    allow(post).to receive(:get_field_object).with('pattern').and_return(nil)

    expect { post.save_field_value('pattern', true) }.not_to raise_error
    expect(post.custom_field_values.where(custom_field_slug: 'pattern')).not_to be_empty
  end
end
