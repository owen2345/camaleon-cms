# frozen_string_literal: true

# The boot-time canonical registry of shortcode NAMES that makes precise save-time detection
# possible: the per-request CurrentRequest.shortcodes list is empty at an admin save, so the gate
# consults this process-wide set instead. Detection mirrors the engine's cama_reg_shortcode regex
# shape (a name is a match only when followed by a space + attributes or an immediate "]"), so
# bracketed prose that is not a registered name is never treated as a shortcode.
RSpec.describe CamaleonCms::ShortcodeRegistry do
  around do |example|
    saved_names = described_class.names
    saved_available = described_class.available?
    example.run
  ensure
    described_class.reset!
    described_class.register(*saved_names)
    described_class.mark_available! if saved_available
  end

  describe '.register / .names (the boot DSL)' do
    it 'aggregates declared names into the canonical set' do
      described_class.reset!
      described_class.register('redirect')
      described_class.register('bootstrap_slider', 'lightbox')

      expect(described_class.names).to include('redirect', 'bootstrap_slider', 'lightbox')
    end

    it 'ignores blank declarations and de-duplicates' do
      described_class.reset!
      described_class.register('redirect', '', '  ', 'redirect')

      expect(described_class.names.to_a).to eq(['redirect'])
    end

    it 'has declared the core-bundled shortcode names at boot' do
      expect(described_class.names).to include('widget', 'load_libraries', 'asset', 'data')
      expect(described_class).to be_available
    end
  end

  describe '.content_has_shortcode? (precise detection)' do
    before do
      described_class.reset!
      described_class.register('redirect', 'data')
      described_class.mark_available!
    end

    it 'flags content containing a registered shortcode' do
      expect(described_class.content_has_shortcode?('hello [redirect url="/x"] world')).to be true
      expect(described_class.content_has_shortcode?('[data key="contact" attr="url"]')).to be true
      expect(described_class.content_has_shortcode?('[redirect]')).to be true
    end

    it 'does not flag unrelated bracketed prose' do
      expect(described_class.content_has_shortcode?('see [figure 2] and [note]')).to be false
      expect(described_class.content_has_shortcode?('[see figure]')).to be false
    end

    it 'does not flag a name that is only a prefix of the bracketed token' do
      expect(described_class.content_has_shortcode?('[redirection now]')).to be false
      expect(described_class.content_has_shortcode?('[database x]')).to be false
    end

    it 'detects a registered name inside any translated locale of the raw stored string' do
      raw = '<!--:en-->plain<!--:--><!--:es-->[redirect url="/y"]<!--:-->'
      expect(described_class.content_has_shortcode?(raw)).to be true
    end

    it 'is false for blank content' do
      expect(described_class.content_has_shortcode?('')).to be false
      expect(described_class.content_has_shortcode?(nil)).to be false
    end
  end

  describe 'fail-closed vs legitimately-empty (D4)' do
    it 'treats any non-blank content as gated when the registry is unavailable (error state)' do
      described_class.reset! # unavailable: boot never completed registration

      expect(described_class).not_to be_available
      expect(described_class.content_has_shortcode?('just plain text, no brackets')).to be true
    end

    it 'gates nothing when the registry is legitimately empty but available' do
      described_class.reset!
      described_class.mark_available! # available, no names declared

      expect(described_class).to be_available
      expect(described_class.content_has_shortcode?('[redirect] anything')).to be false
    end
  end
end
