# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Themes::Default::DefaultHelper do
  # `included` calls `helper_method`, which a plain class lacks; the module rescues that, so a bare
  # includer exercises the helper methods in isolation.
  let(:view) { Class.new { include Themes::Default::DefaultHelper }.new }

  describe '#get_taxonomy' do
    # H11: get_taxonomy builds `<a href='#{the_url}' rel='#{rel}'>` by interpolation, and the default
    # theme renders it through `<%= raw get_taxonomy(...) %>`, so an unescaped taxonomy URL (a category
    # or tag slug persists byte-for-byte) would close the href and inject an event handler.
    it 'escapes the taxonomy href so a malicious slug URL cannot break out of the attribute (H11)' do
      malicious_url = "/category/x' onmouseover='alert(document.domain)"
      taxonomy = double(the_url: malicious_url, the_title: 'Category title')

      result = view.get_taxonomy([taxonomy], 'category')

      expect(result).to include("href='/category/x&#39; onmouseover=&#39;alert(document.domain)'")
      expect(result).not_to include("x' onmouseover='alert(document.domain)")
    end
  end
end
