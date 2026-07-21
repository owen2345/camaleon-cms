# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::TermTaxonomyDecorator do
  describe '#the_title' do
    it 'HTML-escapes the taxonomy name to prevent stored XSS in raw sinks (breadcrumb, nav menu)' do
      post_type = create(:post_type, name: '<img src=x onerror=alert(1)>')

      title = post_type.decorate.the_title

      expect(title).to include('&lt;img')
      expect(title).not_to include('<img src=x onerror')
    end

    it 'preserves plain-text names unchanged' do
      post_type = create(:post_type, name: 'My Section')

      expect(post_type.decorate.the_title).to eq('My Section')
    end
  end
end
