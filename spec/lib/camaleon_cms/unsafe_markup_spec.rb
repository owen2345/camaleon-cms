# frozen_string_literal: true

# Unit coverage for the shared scan-and-reject detector. These reproduce three review findings:
# a data-*/aria-* attribute smuggling entity-encoded markup past the gate (M1), a mis-encoded value
# crashing the gate instead of yielding a verdict (M9), and the over-size ceiling / message (M16).
RSpec.describe CamaleonCms::UnsafeMarkup do
  let(:tags) { CamaleonCms::Post::CONTENT_ALLOWED_TAGS }
  let(:attributes) { CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES }

  def unsafe?(value)
    described_class.unsafe_html?(value, tags: tags, attributes: attributes)
  end

  describe '.unsafe_html? attribute-smuggled markup (M1)' do
    it 'rejects entity-encoded markup hidden in a data attribute (Bootstrap data-html sink)' do
      payload = '<a rel="popover" data-toggle="popover" data-html="true" ' \
                'data-content="&lt;img src=x onerror=alert(1)&gt;">x</a>'

      expect(unsafe?(payload)).to be true
    end

    it 'rejects entity-encoded markup hidden in an allowed attribute (title)' do
      expect(unsafe?('<span title="&lt;img src=x onerror=alert(1)&gt;">x</span>')).to be true
    end

    it 'rejects literal markup written into an attribute value' do
      expect(unsafe?('<a data-content="<img src=x onerror=alert(1)>">x</a>')).to be true
    end

    it 'accepts benign data-*/aria-* attributes with ordinary values' do
      expect(unsafe?('<span data-toggle="tooltip" aria-label="hi" title="plain">hi</span>')).to be false
    end

    it 'accepts ordinary layout markup and links' do
      expect(unsafe?('<p id="lead" style="color:red">t</p><a href="/x" target="_blank" rel="noopener">l</a>'))
        .to be false
    end
  end

  describe '.unsafe_html? with mis-encoded input (M9)' do
    it 'returns a verdict instead of raising on invalid UTF-8' do
      value = (+"abc\xFF<p>ok</p>").force_encoding('UTF-8')

      expect { unsafe?(value) }.not_to raise_error
    end

    it 'still detects markup in a mis-encoded value' do
      value = (+"bad\xFF<script>alert(1)</script>").force_encoding('UTF-8')

      expect(unsafe?(value)).to be true
    end

    it 'does not mutate the caller-supplied string' do
      value = (+"abc\xFF").force_encoding('UTF-8')

      unsafe?(value)

      expect(value.bytes).to eq((+"abc\xFF").force_encoding('UTF-8').bytes)
    end
  end

  describe '.too_large? (M16)' do
    it 'is true above the ceiling and false below it' do
      expect(described_class.too_large?('a' * (described_class::MAX_GATED_VALUE_BYTES + 1))).to be true
      expect(described_class.too_large?('a' * 100_000)).to be false
    end

    it 'accepts a long but clean post that the old 64 KiB cap refused' do
      long_clean = "<p>#{'word ' * 20_000}</p>" # ~100 KB, well over the old 64 KiB limit

      expect(long_clean.bytesize).to be > 64 * 1024
      expect(unsafe?(long_clean)).to be false
    end
  end
end
