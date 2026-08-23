# frozen_string_literal: true

RSpec.describe CamaleonCms::Post, type: :model do
  describe 'validating a post with no slug' do
    let(:post_type) { CamaleonCms::Site.first.post_types.find_by(slug: 'post') }

    # PostUniqValidator calls record.slug.to_s.translations_array; with no slug that
    # receiver is Ruby 3.4's frozen shared empty string, which raised FrozenError before
    # the validator could report anything.
    it 'reports validation results instead of raising' do
      record = described_class.new(title: 'No slug', post_type: post_type)

      expect { record.valid? }.not_to raise_error
    end

    it 'does not raise when saved through a post type' do
      expect { post_type.posts.new(title: 'No slug').valid? }.not_to raise_error
    end
  end
end
