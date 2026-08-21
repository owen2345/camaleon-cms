# frozen_string_literal: true

require 'rails_helper'

# The with_eager scope carries the eager-loading contract for frontend post listings:
# verify_front_visibility applies it instead of inlining a drifting copy (PR #1169
# review, WITH-EAGER-DEAD). This pins the association list and that it stays a
# preload-shaped (includes) relation, not a join.
RSpec.describe CamaleonCms::Post, type: :model do
  describe '.with_eager' do
    it 'includes the metas, categories and post_type metas relations' do
      relation = described_class.with_eager

      expect(relation.includes_values).to include(:metas, :categories, post_type: :metas)
      expect(relation.eager_load_values).to be_empty
    end
  end
end
