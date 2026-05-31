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

  describe '#theme_view' do
    let(:current_theme) do
      instance_double(
        CamaleonCms::Theme,
        slug: 'default',
        settings: { 'gem_mode' => false }
      )
    end

    before do
      allow(theme_helper).to receive(:current_theme).and_return(current_theme)
    end

    it 'warns when called with the deprecated second argument' do
      expect(ActiveSupport::Deprecation._instance).to receive(:warn).with(
        include('Passing theme view name as the second argument to #theme_view is deprecated')
      )

      expect(theme_helper.theme_view('ignored', 'index')).to eq('themes/default/views/index')
    end
  end
end
