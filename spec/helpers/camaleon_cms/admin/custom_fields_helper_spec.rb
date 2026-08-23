# frozen_string_literal: true

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

  describe '#cf_extra_models_for_fields (regression M18)' do
    it 'returns models registered through cf_add_model so they reach the placement dropdown' do
      helper.cf_add_model(CamaleonCms::Post)

      expect(helper.cf_extra_models_for_fields).to include(CamaleonCms::Post)
    end

    it 'includes models appended by a custom_field_custom_models hook' do
      allow(helper).to receive(:hooks_run) { |_key, args| args[:models] << CamaleonCms::User }

      expect(helper.cf_extra_models_for_fields).to include(CamaleonCms::User)
    end

    it 'does not accumulate hook-appended models across repeated calls' do
      helper.cf_add_model(CamaleonCms::Post)
      allow(helper).to receive(:hooks_run) { |_key, args| args[:models] << CamaleonCms::User }

      first = helper.cf_extra_models_for_fields
      second = helper.cf_extra_models_for_fields

      expect(first).to eq([CamaleonCms::Post, CamaleonCms::User])
      expect(second).to eq(first)
      expect(CurrentRequest.extra_models_for_fields).to eq([CamaleonCms::Post])
    end

    it 'seeds from a controller-assigned legacy @_extra_models_for_fields without mutating it' do
      legacy = [CamaleonCms::Post]
      helper.instance_variable_set(:@_extra_models_for_fields, legacy)
      allow(helper).to receive(:hooks_run) { |_key, args| args[:models] << CamaleonCms::User }

      expect(helper.cf_extra_models_for_fields).to eq([CamaleonCms::Post, CamaleonCms::User])
      expect(legacy).to eq([CamaleonCms::Post])
    end
  end
end
