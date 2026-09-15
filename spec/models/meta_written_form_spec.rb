# frozen_string_literal: true

# set_meta memoized the value as the caller passed it while a reload read the parsed stored form, so a
# String that stores as a number, a boolean or JSON, and a Hash with Symbol keys, read differently on the
# writing instance than on a freshly loaded record, and a plugin's own hash was handed back, so a change
# made to it afterwards was read on that instance without a write.
RSpec.describe CamaleonCms::Post, type: :model do
  let(:post_type) { CamaleonCms::Site.first.post_types.find_by!(slug: 'post') }

  describe '#set_meta' do
    {
      '2024' => 2024, '1.5' => 1.5, 'true' => true, 'false' => false, '[1, 2]' => [1, 2],
      'plain text' => 'plain text', :symbol => 'symbol', 7 => 7, true => true
    }.each do |written, read|
      it "reads #{written.inspect} back as #{read.inspect} on the writing instance, as after a reload" do
        post = create(:post, post_type: post_type)
        post.set_meta('probe', written)

        expect(post.get_meta('probe')).to eq(read)
        expect(described_class.find(post.id).get_meta('probe')).to eq(read)
      end
    end

    it "reads a hash back by either key type, leaving the caller's hash as passed" do
      post = create(:post, post_type: post_type)
      passed = { color: 'red', sizes: [{ top: 'xl' }] }
      post.set_meta('probe', passed)
      read = post.get_meta('probe')

      expect([read[:color], read['color'], read[:sizes].first['top']]).to eq(%w[red red xl])
      expect(read).not_to equal(passed)
      expect(passed.keys).to eq(%i[color sizes])
      passed[:color] = 'blue'
      expect(post.get_meta('probe')[:color]).to eq('red')
      expect(described_class.find(post.id).get_meta('probe')).to eq(read)
    end

    it 'reads a JSON string back as the value it holds' do
      post = create(:post, post_type: post_type)
      post.set_meta('probe', '{"color": "red"}')

      expect(post.get_meta('probe')).to eq('color' => 'red')
      expect(post.get_meta('probe')[:color]).to eq('red')
      expect(described_class.find(post.id).get_meta('probe')).to eq('color' => 'red')
    end

    it 'reads the written value the same way before and after the first save' do
      post = build(:post, post_type: post_type)
      post.set_meta('probe', '2024')
      expect(post.get_meta('probe')).to eq(2024)

      post.save!

      expect(post.get_meta('probe')).to eq(2024)
    end
  end
end
