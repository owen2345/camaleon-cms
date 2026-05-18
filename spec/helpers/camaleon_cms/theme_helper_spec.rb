# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::ThemeHelper do
  let(:theme_helper) do
    Class.new do
      include CamaleonCms::ThemeHelper
    end.new
  end

  describe '#theme_init' do
    it 'stores breadcrumb state in CurrentRequest' do
      theme_helper.theme_init

      state = CurrentRequest.theme_helper_state
      expect(state[:front_breadcrumb]).to eq([])
    end
  end
end
