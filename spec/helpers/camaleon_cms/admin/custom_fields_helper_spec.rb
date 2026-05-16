# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::CustomFieldsHelper, type: :helper do
  include described_class

  before do
    CurrentRequest.reset
    allow(helper).to receive(:hooks_run)
  end

  describe 'custom field model registry with CurrentRequest' do
    it 'adds models to CurrentRequest.extra_models_for_fields' do
      CurrentRequest.extra_models_for_fields = []
      cf_add_model('Product')

      expect(CurrentRequest.extra_models_for_fields).to include('Product')
    end

    it 'initializes extra_models_for_fields in CurrentRequest if not present' do
      CurrentRequest.extra_models_for_fields = nil
      cf_add_model('Product')

      expect(CurrentRequest.extra_models_for_fields).not_to be_nil
      expect(CurrentRequest.extra_models_for_fields).to include('Product')
    end

    it 'persists registry across multiple adds' do
      CurrentRequest.extra_models_for_fields = []
      cf_add_model('Product')
      cf_add_model('Service')

      expect(CurrentRequest.extra_models_for_fields).to include('Product', 'Service')
    end
  end
end
