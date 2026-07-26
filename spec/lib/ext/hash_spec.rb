# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hash do
  # Both methods carry a `gsub('"', '\"')`, which escapes for a Ruby string literal rather than for
  # the context each method actually emits. A backslash escapes nothing in HTML, so the quote still
  # closes the attribute and whatever follows is parsed as further markup.
  describe '#to_attr_format' do
    # Parse the produced attribute list the way a browser would, so the assertions describe what the
    # markup *means* rather than which escaping scheme produced it.
    def attributes_of(hash)
      Nokogiri::HTML5.fragment("<input #{hash.to_attr_format}>").at_css('input').attributes.transform_values(&:value)
    end

    it 'does not let a double quote in a value terminate the attribute' do
      attrs = attributes_of({ class: 'x" onfocus=alert(1) y="' })

      expect(attrs.keys).to contain_exactly('class')
      expect(attrs).not_to have_key('onfocus')
    end

    it 'does not treat a backslash as an escape for the quote that follows it' do
      attrs = attributes_of({ 'data-x' => 'a\\"b' })

      expect(attrs.keys).to contain_exactly('data-x')
      expect(attrs['data-x']).to eq('a\\"b')
    end

    it 'keeps angle brackets inside the value instead of opening an element' do
      fragment = Nokogiri::HTML5.fragment(
        "<input #{{ 'data-x' => '</textarea><script>alert(1)</script>' }.to_attr_format}>"
      )

      expect(fragment.css('script')).to be_empty
      expect(fragment.at_css('input')['data-x']).to eq('</textarea><script>alert(1)</script>')
    end

    # Escaping cannot defend the key position: the characters that split one attribute name into two
    # are whitespace and `=`, neither of which an HTML escaper touches. Invalid names are dropped.
    it 'drops a key that would render as more than one attribute' do
      attrs = attributes_of({ 'x onfocus=alert(1) y' => '1' })

      expect(attrs).to be_empty
    end

    it 'drops a key carrying a quote or a slash' do
      expect(attributes_of({ 'a"b' => '1' })).to be_empty
      expect(attributes_of({ 'a/onfocus' => '1' })).to be_empty
    end

    it 'keeps the attribute-name shapes real callers use' do
      attrs = attributes_of({ id: 'a', 'data-x' => 'b', 'aria-label' => 'c', class: 'd' })

      expect(attrs.keys).to contain_exactly('id', 'data-x', 'aria-label', 'class')
    end

    it 'leaves values without HTML-significant characters byte-identical' do
      expect({ id: 'field_3', 'data-role' => 'input' }.to_attr_format)
        .to eq('id = "field_3" data-role = "input"')
    end

    it 'joins pairs with a caller-supplied separator' do
      expect({ a: '1', b: '2' }.to_attr_format(', ')).to eq('a = "1", b = "2"')
    end
  end

  describe '#to_attr_url_format' do
    # This one emits a Ruby-ish `:key => "value"` fragment for code generation, not HTML, so it needs
    # an escaper for a double-quoted Ruby literal — entity-encoding would corrupt the generated code.
    # Its quote handling is already right for that context; what it misses is the backslash, which is
    # itself an escape character inside a double-quoted literal.
    def round_trip(value)
      eval("{ #{{ key: value }.to_attr_url_format} }", binding, __FILE__, __LINE__)[:key] # rubocop:disable Security/Eval
    end

    it 'keeps a value containing a double quote inside one well-formed literal' do
      expect(round_trip('a"b')).to eq('a"b')
    end

    it 'preserves a literal backslash instead of forming an escape sequence' do
      expect(round_trip('a\\b')).to eq('a\\b')
    end

    it 'survives a backslash immediately preceding a quote' do
      expect { round_trip('a\\"b') }.not_to raise_error
      expect(round_trip('a\\"b')).to eq('a\\"b')
    end

    it 'does not introduce HTML entities' do
      generated = { key: 'a<b & c' }.to_attr_url_format

      expect(generated).to include('a<b & c')
      expect(generated).not_to include('&lt;', '&amp;')
    end
  end
end
