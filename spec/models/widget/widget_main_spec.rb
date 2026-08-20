# frozen_string_literal: true

require 'rails_helper'
require 'shared_specs/sanitize_attrs'

RSpec.describe CamaleonCms::Widget::Main, type: :model do
  describe 'native STI compatibility' do
    it 'uses legacy widget taxonomy as sti_name' do
      expect(described_class.sti_name).to eq('widget')
    end
  end
end
