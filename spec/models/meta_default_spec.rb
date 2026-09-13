# frozen_string_literal: true

# get_meta memoizes each meta a record reads. For a meta with no value it memoized the default of the first
# read, so later reads on the same instance returned that default, or the caller's in-place changes to it,
# instead of their own, while a freshly loaded record returned each read's own default.
RSpec.describe CamaleonCms::Post, type: :model do
  describe '#get_meta for a meta with no value' do
    it 'returns the default each read passes', :aggregate_failures do
      post = create(:post)

      [post, described_class.find(post.id), described_class.includes(:metas).find(post.id)].each do |record|
        expect(record.get_meta('gallery')).to be_nil
        expect(record.get_meta('gallery', [])).to eq([])
      end
    end

    it 'does not return a default a caller changed in place' do
      post = create(:post)
      post.get_meta('gallery', []) << 'photo.jpg'

      expect(post.get_meta('gallery', [])).to eq([])
    end

    it 'returns the default each read passes for a meta stored as an empty string' do
      post = create(:post)
      post.metas.create!(key: 'gallery', value: '')
      stored = described_class.find(post.id)

      expect(stored.get_meta('gallery')).to be_nil
      expect(stored.get_meta('gallery', [])).to eq([])
    end

    it 'reads a missing meta from the database once' do
      post = described_class.find(create(:post).id)

      queries = sql_queries(matching: /metas/) do
        post.get_meta('gallery')
        post.get_meta('gallery', [])
        post.get_meta('gallery', {})
      end

      expect(queries.size).to eq(1)
    end
  end

  describe '#set_meta with an empty string' do
    it 'reads back as the default on the writing instance, as after a reload' do
      post = create(:post)
      post.set_meta('gallery', '')

      expect(post.get_meta('gallery', [])).to eq([])
      expect(described_class.find(post.id).get_meta('gallery', [])).to eq([])
    end
  end
end
