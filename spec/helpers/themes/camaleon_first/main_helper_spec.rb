# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('app/apps/themes/camaleon_first/main_helper')

RSpec.describe Themes::CamaleonFirst::MainHelper, type: :helper do
  before do
    helper.singleton_class.include(described_class)
  end

  describe '#camaleon_first_list_select' do
    it 'escapes option labels and values' do
      post_type = double(the_slug: 'bad"slug', the_title: '<script>alert(1)</script>')
      allow(helper).to receive(:current_site).and_return(double(the_post_types: double(decorate: [post_type])))

      output = helper.camaleon_first_list_select

      expect(output).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
      expect(output).to include('value="bad&quot;slug"')
      expect(output).not_to include('<script>')
    end
  end
end
