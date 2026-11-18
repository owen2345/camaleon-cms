# frozen_string_literal: true

RSpec.describe String do
  # cama_contact_form gives this method the values that a visitor sends, and camaleon-ecommerce the data
  # of an order. String#gsub with a String replacement reads a backslash sequence in the value, and each
  # later gsub searched the values that an earlier one put in.
  describe '#cama_replace_codes' do
    let(:backslashes) { %q(\0 \& \' \` \\\\ \1 \k<x>) }

    it 'shows a backslash sequence of a value as written' do
      expect('Hi [c1]!'.cama_replace_codes(c1: backslashes)).to eq("Hi #{backslashes}!")
    end

    it 'does not replace the code of a later value inside an earlier value' do
      expect('[c1] [c2]'.cama_replace_codes(c1: '<b title="[c2]">', c2: 'x')).to eq('<b title="[c2]"> x')
    end

    # rubocop:disable Style/FormatStringToken -- `%{b}` is a code of cama_replace_codes, not a format.
    it 'replaces each code of the brace formats' do
      expect('{a} %{b}'.cama_replace_codes({ a: 1 }, '{')).to eq('1 %{b}')
      expect('{a} %{b}'.cama_replace_codes({ b: 2 }, '%{')).to eq('{a} 2')
    end
    # rubocop:enable Style/FormatStringToken

    it 'joins a list value with commas, and replaces each place of a code' do
      expect('[c1] and [c1]'.cama_replace_codes(c1: %w[a b])).to eq('a,b and a,b')
    end

    it 'takes the first value of a key that is given as a Symbol and as a String' do
      expect('[c1]'.cama_replace_codes({ c1: 'first', 'c1' => 'second' })).to eq('first')
    end

    # A Regexp raises an ArgumentError on a text with invalid bytes, such as a Latin-1 template that
    # Ruby reads as UTF-8. The loop before replaced the codes of such a text.
    it 'replaces the codes of a text with invalid bytes in one pass, and keeps its encoding' do
      text = (+"Caf\xE9 [c1] [c2] [é]").force_encoding(Encoding::UTF_8)
      expect(text).not_to be_valid_encoding

      result = text.cama_replace_codes('c1' => '\0 [c2]', 'c2' => 'x', 'é' => 'y')

      expect(result.b).to eq("Caf\xE9 \\0 [c2] x y".b)
      expect(result.encoding).to eq(Encoding::UTF_8)
    end

    it 'returns the text as it is for an unknown format' do
      expect('[c1]'.cama_replace_codes({ c1: 'x' }, '<')).to eq('[c1]')
    end
  end
end
