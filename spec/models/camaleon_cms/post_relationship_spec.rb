# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::PostRelationship, type: :model do
  it 'allows destroying a post with legacy post_relationship rows' do
    post = create(:post)
    post_type = post.post_type

    described_class.create!(objectid: post.id, term_taxonomy_id: post_type.id, term_order: 0)

    expect { post.destroy! }.not_to raise_error
  end
end
