# frozen_string_literal: true

require 'rails_helper'

RSpec.describe String do
  describe '#translations' do
    # Ruby 3.4's nil.to_s returns a frozen (and globally shared) empty string, and every
    # string literal in a `frozen_string_literal: true` file is frozen too. Memoizing the
    # parsed translations in an ivar on the receiver therefore raised FrozenError for any
    # such string instead of returning its (empty) translation set.
    it 'does not raise for a frozen receiver' do
      expect { nil.to_s.translations }.not_to raise_error
    end

    it 'returns an empty set for a frozen blank string' do
      expect(nil.to_s.translations).to eq({})
    end

    it 'parses locale markers on a frozen string' do
      frozen = (+'<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->').freeze

      expect(frozen.translations).to eq({ en: 'Hello', es: 'Hola' })
    end

    it 'still parses locale markers on a mutable string' do
      expect((+'<!--:en-->Hello<!--:-->').translations).to eq({ en: 'Hello' })
    end
  end

  describe '#translations_array' do
    it 'does not raise for a frozen receiver' do
      expect { nil.to_s.translations_array }.not_to raise_error
    end

    it 'returns the receiver itself when it carries no locale markers' do
      expect(nil.to_s.translations_array).to eq([''])
    end
  end

  describe '#translate' do
    it 'does not raise for a frozen receiver' do
      expect { nil.to_s.translate(:en) }.not_to raise_error
    end

    it 'translates a frozen multilingual string' do
      frozen = (+'<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->').freeze

      expect(frozen.translate(:es)).to eq('Hola')
    end
  end
end
