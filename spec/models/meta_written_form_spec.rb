# frozen_string_literal: true

# set_meta memoized the value as the caller passed it while a reload read the parsed stored form, so a
# String that stores as a number, a boolean or JSON, and a Hash with Symbol keys, read differently on the
# writing instance than on a freshly loaded record, and a plugin's own hash or String was handed back, so a
# change made to it afterwards was read on that instance without a write, and an html_safe String rendered
# unescaped there until a reload.
RSpec.describe CamaleonCms::Post, type: :model do
  let(:post_type) { installed_post_type }
  let(:post) { create(:post, post_type: post_type) }

  describe '#set_meta' do
    {
      '2024' => 2024, '1.5' => 1.5, 'true' => true, 'false' => false, '[1, 2]' => [1, 2],
      'plain text' => 'plain text', :symbol => 'symbol', 7 => 7, true => true,
      ' 42 ' => 42, '-5' => -5, 'NaN' => 'NaN', '<b>7</b>' => '<b>7</b>', 't' => 't', 'f' => 'f',
      :t => 't', :f => 'f', BigDecimal('19.99') => 19.99, Time.utc(2026, 9, 22, 10) => '2026-09-22 10:00:00 UTC',
      Date.new(2026, 9, 22) => '2026-09-22'
    }.each do |written, read|
      it "reads #{written.inspect} back as #{read.inspect} on the writing instance, as after a reload" do
        post.set_meta('probe', written)

        expect(post.get_meta('probe')).to eq(read)
        expect(described_class.find(post.id).get_meta('probe')).to eq(read)
      end
    end

    # The bare letter is how the text column cast a boolean before booleans were stored as their JSON literal,
    # and a row holding it still reads as that boolean, so a value whose text is one letter, a String or a
    # Symbol, is stored as its JSON string.
    it "stores a String or a Symbol 't' or 'f' as its JSON string, apart from the booleans stored as the letter" do
      post.set_meta('probe', 'f')
      post.set_meta('probe_symbol', :t)
      post.metas.create!(key: 'probe_legacy', value: 'f')
      reloaded = described_class.find(post.id)

      expect(post.metas.where(key: %w[probe probe_symbol]).order(:key).pluck(:value)).to eq(['"f"', '"t"'])
      expect(%w[probe probe_symbol probe_legacy].map { |key| reloaded.get_meta(key) }).to eq(['f', 't', false])
    end

    # set_meta returns the value it was passed, as 2.9.4 did, whatever form a read returns for it, and the
    # option writers return the options the record reads after the write, from its first options write on.
    it 'returns the value passed, and the option writers the options the record reads' do
      params = ActionController::Parameters.new(color: 'red')

      expect([post.set_meta('probe', 'false'), post.set_meta('probe', 'null')]).to eq(%w[false null])
      expect(post.set_meta('probe', params)).to equal(params)
      expect(post.get_meta('_default')).to be_nil
      written = post.set_options(size: 'xl')
      expect(written).to equal(post.options)
      post.set_option(:color, 'red')
      expect(written[:color]).to eq('red')
      expect(post.delete_option(:size)).to equal(post.options)
    end

    it "reads a hash back by either key type, leaving the caller's hash as passed" do
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
      allow(JSON).to receive(:parse).and_call_original
      expect(JSON).not_to receive(:parse).with('https://example.com/photo.jpg', any_args)

      post.set_meta('probe', 'https://example.com/photo.jpg')
      reads = [post.get_meta('probe'), described_class.find(post.id).get_meta('probe')]

      expect(reads).to eq(%w[https://example.com/photo.jpg https://example.com/photo.jpg])
    end

    # Which text can open a JSON text is the json gem's grammar, which the skip mirrors, so it is held to the
    # parser installed: text opening with any ASCII character or a Unicode space, after any whitespace, reads
    # as the value the parser finds in it, or as the text when the parser finds none.
    it 'reads text as the installed json parser reads it, whatever it opens with' do
      unsaved = build(:post, post_type: post_type)
      prefixes = ['', ' ', "\t", "\n", "\r", "\f", "\v", "\u00A0", "\uFEFF"]
      openings = (0..127).map(&:chr) + ["\u00A0", "\uFEFF", "\u3000", '１']
      rests = ['', '1', '{}', '[]', '"a"', 'rue', 'alse', 'ull', 'aN', 'nfinity', "/ c\n1", '* c */1', "\n1", ' 1']
      texts = prefixes.product(openings, rests).map(&:join)

      expect(texts.reject { |text| unsaved.send(:stored_form_of, text) == parser_read(text) }).to be_empty
    end

    def parser_read(text)
      CamaleonCms::Metas.indifferent_json_value(JSON.parse(text, allow_duplicate_key: true))
    rescue StandardError
      text
    end

    # A number reads back as itself, so it is memoized without parsing its text back, as a counter such as a
    # post's visits, written on every view, was.
    it 'reads a number it writes back without parsing its text' do
      expect(post).to be_persisted
      expect(JSON).not_to receive(:parse)

      post.set_meta('visits', 42)
      post.set_meta('ratio', 0.5)

      expect([post.get_meta('visits'), post.get_meta('ratio')]).to eq([42, 0.5])
    end

    it "reads plain text back as a String of its own, leaving the caller's String as passed" do
      passed = +'plain text'
      post.set_meta('probe', passed)

      expect(post.get_meta('probe')).not_to equal(passed)
      passed << ' changed after the write'
      expect(post.get_meta('probe')).to eq('plain text')
      expect(described_class.find(post.id).get_meta('probe')).to eq('plain text')
    end

    # The database stores text in UTF-8, so text in another encoding reads back transcoded after a reload; the
    # writing instance reads it the same way, not in the caller's encoding, which UTF-8 text cannot be joined to.
    it 'reads text in another encoding back as the UTF-8 text a reloaded record reads' do
      post.set_meta('probe', String.new("caf\xE9", encoding: Encoding::ISO_8859_1))

      reads = [post.get_meta('probe'), described_class.find(post.id).get_meta('probe')]
      expect(reads).to eq(%w[café café])
      expect(reads.map(&:encoding)).to eq([Encoding::UTF_8, Encoding::UTF_8])
    end

    it 'reads an html_safe String back as the plain String a reloaded record reads' do
      post.set_meta('probe', ActiveSupport::SafeBuffer.new('<b>bold</b>'))
      reloaded = described_class.find(post.id)

      expect([post.get_meta('probe'), reloaded.get_meta('probe')]).to eq(['<b>bold</b>', '<b>bold</b>'])
      expect([post.get_meta('probe').html_safe?, reloaded.get_meta('probe').html_safe?]).to eq([false, false])
    end

    # The stored form takes the text of a value before it rescues a parse, so a value whose text cannot be
    # taken raises its own error before the write is checked, instead of reading as a meta with no value.
    it 'raises the error of a value whose text cannot be taken, before checking the write' do
      unreadable = Object.new
      unreadable.define_singleton_method(:to_s) { raise ArgumentError, 'no text' }
      expect(post).not_to receive(:check_meta_write)

      expect { post.set_meta('probe', unreadable) }.to raise_error(ArgumentError, 'no text')
      expect(described_class.find(post.id).get_meta('probe')).to be_nil
    end

    it 'reads a JSON string back as the value it holds' do
      post.set_meta('probe', '{"color": "red"}')

      expect(post.get_meta('probe')).to eq('color' => 'red')
      expect(post.get_meta('probe')[:color]).to eq('red')
      expect(described_class.find(post.id).get_meta('probe')).to eq('color' => 'red')
    end

    it 'reads the written value the same way before and after the first save' do
      unsaved = build(:post, post_type: post_type)
      unsaved.set_meta('probe', '2024')
      expect(unsaved.get_meta('probe')).to eq(2024)

      unsaved.save!

      expect(unsaved.get_meta('probe')).to eq(2024)
    end
  end
end
