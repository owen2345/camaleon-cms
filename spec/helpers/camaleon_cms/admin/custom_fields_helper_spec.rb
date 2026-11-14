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

  describe '#cama_custom_field_elements' do
    before { allow(helper).to receive(:current_site).and_return(CamaleonCms::Site.first) }

    it 'gives each field type its own options, so a hook that edits one type changes no other type' do
      allow(helper).to receive(:hooks_run).with('extra_custom_fields', anything) do |_name, args|
        args[:fields][:audio][:options][:required] = false
        args[:fields][:file][:extra_fields].first[:label] = 'Changed'
      end

      fields = helper.cama_custom_field_elements

      expect(fields[:audio][:options][:required]).to be(false)
      expect(fields[:video][:options][:required]).to be(true)
      expect(fields[:private_file][:extra_fields].first[:label]).to eq('File Formats (image,video,audio)')
    end

    it 'gives the next request the options as the table defines them' do
      allow(helper).to receive(:hooks_run).with('extra_custom_fields', anything) do |_name, args|
        args[:fields][:audio][:options][:required] = false
      end
      helper.cama_custom_field_elements
      CurrentRequest.reset
      allow(helper).to receive(:hooks_run)

      expect(helper.cama_custom_field_elements[:audio][:options][:required]).to be(true)
    end
  end

  describe '#cama_submitted_field_values' do
    def submitted(payload)
      helper.cama_submitted_field_values(ActionController::Parameters.new(field_options: payload)[:field_options])
    end

    it 'reads the values of each field of each group, in the order of submission' do
      payload = { '0' => { 'note' => { 'id' => '1', 'values' => { '1' => 'b', '0' => 'a' } } },
                  '1' => { 'note' => { 'id' => '1', 'values' => %w[c] } } }

      expect(submitted(payload)).to eq([{ 'note' => %w[b a] }, { 'note' => %w[c] }])
    end

    it 'gives an empty list for a param that is not a set of groups' do
      expect(submitted('foo')).to eq([])
      expect(submitted(%w[a b])).to eq([])
    end

    it 'leaves out a group that is not a set of fields' do
      expect(submitted({ '0' => 'x', '1' => { 'note' => { 'values' => %w[a] } } })).to eq([{ 'note' => %w[a] }])
    end

    it 'leaves out a field entry that is not a set of attributes' do
      expect(submitted({ '0' => { 'note' => %w[x], 'title' => 'x', 'kept' => { 'values' => %w[a] } } }))
        .to eq([{ 'kept' => %w[a] }])
    end
  end

  describe '#cama_form_field_values' do
    let(:record) { instance_double(CamaleonCms::Post) }
    let(:submitted) { { '0' => { 'note' => { 'values' => ['typed'] } } } }

    # The record gives its values only for the slugs of the group.
    before { allow(record).to receive(:get_fields_grouped).with(['note']).and_return([{ 'note' => ['stored'] }]) }

    def values_for(verb, params = {})
      helper.request.request_method = verb
      controller.params = ActionController::Parameters.new(params)
      helper.cama_form_field_values(record, ['note'])
    end

    it 'gives the values of the record for a GET request with field values' do
      expect(values_for('GET', field_options: submitted)).to eq([{ 'note' => ['stored'] }])
    end

    %w[POST PATCH PUT].each do |verb|
      it "gives the submitted values for a #{verb} request with field values" do
        expect(values_for(verb, field_options: submitted)).to eq([{ 'note' => ['typed'] }])
      end
    end

    it 'gives the values of the record for a POST request with no field values' do
      expect(values_for('POST')).to eq([{ 'note' => ['stored'] }])
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
