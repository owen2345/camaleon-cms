# frozen_string_literal: true

# set_meta memoized the value as the caller passed it while a reload read the parsed stored form, so a
# String that stores as a number, a boolean or JSON, and a Hash with Symbol keys, read differently on the
# writing instance than on a freshly loaded record, and a plugin's own hash or String was handed back, so a
# change made to it afterwards was read on that instance without a write, and an html_safe String rendered
# unescaped there until a reload.
RSpec.describe CamaleonCms::Post, type: :model do
  let(:post_type) { CamaleonCms::Site.first.post_types.find_by!(slug: 'post') }

  describe '#set_meta' do
    {
      '2024' => 2024, '1.5' => 1.5, 'true' => true, 'false' => false, '[1, 2]' => [1, 2],
      'plain text' => 'plain text', :symbol => 'symbol', 7 => 7, true => true,
      ' 42 ' => 42, '-5' => -5, 'NaN' => 'NaN', '<b>7</b>' => '<b>7</b>'
    }.each do |written, read|
      it "reads #{written.inspect} back as #{read.inspect} on the writing instance, as after a reload" do
        post = create(:post, post_type: post_type)
        post.set_meta('probe', written)

        expect(post.get_meta('probe')).to eq(read)
        expect(described_class.find(post.id).get_meta('probe')).to eq(read)
      end
    end

    # set_meta returns the value it was passed, as 2.9.4 did, whatever form a read returns for it, and the
    # option writers return the options they wrote.
    it 'returns the value passed, and the option writers the options they wrote' do
      post = create(:post, post_type: post_type)
      params = ActionController::Parameters.new(color: 'red')

      expect([post.set_meta('probe', 'false'), post.set_meta('probe', 'null')]).to eq(%w[false null])
      expect(post.set_meta('probe', params)).to equal(params)
      expect(post.set_options(size: 'xl')).to eq(post.options)
      expect(post.delete_option(:size)).to eq(post.options)
    end

    it "reads a hash back by either key type, leaving the caller's hash as passed" do
      post = create(:post, post_type: post_type)
      passed = { color: 'red', sizes: [{ top: 'xl' }] }
      post.set_meta('probe', passed)
      read = post.get_meta('probe')

      expect([read[:color], read['color'], read[:sizes].first['top']]).to eq(%w[red red xl])
      expect(read).to be_a(ActiveSupport::HashWithIndifferentAccess)
      expect(read).not_to equal(passed)
      expect(passed.keys).to eq(%i[color sizes])
      passed[:color] = 'blue'
      passed[:size] = 'm'
      expect(post.get_meta('probe')[:color]).to eq('red')
      expect(post.get_meta('probe')).not_to have_key(:size)
      expect(described_class.find(post.id).get_meta('probe')).to eq(read)
    end

    # No JSON text opens with a letter other than t, f or n, so such text is read as the text it is,
    # without a parse that could only fail.
    it 'reads back text that cannot hold JSON without parsing it' do
      post = create(:post, post_type: post_type)
      allow(JSON).to receive(:parse).and_call_original
      expect(JSON).not_to receive(:parse).with('https://example.com/photo.jpg', any_args)

      post.set_meta('probe', 'https://example.com/photo.jpg')
      reads = [post.get_meta('probe'), described_class.find(post.id).get_meta('probe')]

      expect(reads).to eq(%w[https://example.com/photo.jpg https://example.com/photo.jpg])
    end

    it "reads plain text back as a String of its own, leaving the caller's String as passed" do
      post = create(:post, post_type: post_type)
      passed = +'plain text'
      post.set_meta('probe', passed)

      expect(post.get_meta('probe')).not_to equal(passed)
      passed << ' changed after the write'
      expect(post.get_meta('probe')).to eq('plain text')
      expect(described_class.find(post.id).get_meta('probe')).to eq('plain text')
    end

    it 'reads an html_safe String back as the plain String a reloaded record reads' do
      post = create(:post, post_type: post_type)
      post.set_meta('probe', ActiveSupport::SafeBuffer.new('<b>bold</b>'))
      reloaded = described_class.find(post.id)

      expect([post.get_meta('probe'), reloaded.get_meta('probe')]).to eq(['<b>bold</b>', '<b>bold</b>'])
      expect([post.get_meta('probe').html_safe?, reloaded.get_meta('probe').html_safe?]).to eq([false, false])
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
