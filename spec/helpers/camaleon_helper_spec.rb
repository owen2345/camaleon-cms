# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::CamaleonHelper, type: :helper do
  describe '#cama_pluralize_text' do
    # `SafeBuffer#pluralize` returns a plain String, so the safe flag is gone before the call site
    # can compose with it. The helper propagates the safeness it was given -- and only that.
    it 'keeps a safe input safe' do
      result = helper.cama_pluralize_text('Ben &amp; Jerry Cake'.html_safe)

      expect(result).to eq('Ben &amp; Jerry Cakes')
      expect(result).to be_html_safe
    end

    it 'leaves an unsafe input unsafe' do
      result = helper.cama_pluralize_text('<b>x</b>')

      expect(result).to eq('<b>x</b>s')
      expect(result).not_to be_html_safe
    end

    it 'returns nil for nil' do
      expect(helper.cama_pluralize_text(nil)).to be_nil
    end
  end
end
