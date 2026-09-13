# frozen_string_literal: true

# A record memoizes its meta and option reads per instance. Copies made with dup shared the original's
# memo, and with it their common nil-id keys, so one copy's option write showed in the others; reload kept
# the values read before it.
RSpec.describe CamaleonRecord do
  describe '#dup' do
    it 'keeps an option written on one copy out of another' do
      post = create(:post)
      post.get_option('has_comments')
      first_copy = post.dup
      second_copy = post.dup

      first_copy.set_option('has_comments', true)

      expect(second_copy.get_option('has_comments')).to be_nil
    end
  end

  describe '#reload' do
    it 'reads a meta written through another instance since the last read' do
      post = create(:post)
      post.set_meta('subtitle', 'old')
      CamaleonCms::Post.find(post.id).set_meta('subtitle', 'new')

      expect(post.reload.get_meta('subtitle')).to eq('new')
    end
  end
end
