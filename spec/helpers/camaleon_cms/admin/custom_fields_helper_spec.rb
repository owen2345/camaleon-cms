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

    # With no field_name, the helper reads its default param.
    def values_for(verb, params = {}, *field_name)
      helper.request.request_method = verb
      controller.params = ActionController::Parameters.new(params)
      helper.cama_form_field_values(record, ['note'], *field_name)
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

    it 'gives the submitted values under the field name that it gets' do
      expect(values_for('POST', { theme_fields: submitted }, :theme_fields)).to eq([{ 'note' => ['typed'] }])
    end

    # Each group of the form counts its instances from 0, so one index can hold the fields of two groups.
    it 'gives only the submitted entries that hold a field of the group' do
      two_groups = { '0' => { 'note' => { 'values' => ['typed'] }, 'color' => { 'values' => ['red'] } },
                     '1' => { 'color' => { 'values' => ['blue'] } } }

      expect(values_for('POST', field_options: two_groups)).to eq([{ 'note' => ['typed'] }])
    end

    it 'keeps an entry of a field of the group that submits no value' do
      no_value = { '0' => { 'note' => { 'id' => '12' } }, '1' => { 'color' => { 'values' => ['blue'] } } }

      expect(values_for('POST', field_options: no_value)).to eq([{ 'note' => nil }])
    end

    # The admin dragged the instance of index 2 to the top, so the form gave it the group number 0.
    it 'gives the submitted instances of a sorted repeat group in the order of their group numbers' do
      sorted = { '0' => { 'color' => { 'group_number' => '0' },
                          'note' => { 'group_number' => '1', 'values' => ['first'] } },
                 '2' => { 'note' => { 'group_number' => '0', 'values' => ['third'] } },
                 '1' => { 'note' => { 'group_number' => '2', 'values' => ['second'] } } }

      expect(values_for('POST', field_options: sorted))
        .to eq([{ 'note' => ['third'] }, { 'note' => ['first'] }, { 'note' => ['second'] }])
    end

    it 'gives a submitted instance with an invalid group number after the other instances' do
      invalid = { '0' => { 'note' => { 'group_number' => 'x', 'values' => ['invalid'] } },
                  '1' => { 'note' => { 'group_number' => '1', 'values' => ['valid'] } } }

      expect(values_for('POST', field_options: invalid)).to eq([{ 'note' => ['valid'] }, { 'note' => ['invalid'] }])
    end

    it 'sorts a submitted instance with an empty group number as the group number 0' do
      empty = { '0' => { 'note' => { 'group_number' => '1', 'values' => ['second'] } },
                '1' => { 'note' => { 'group_number' => '', 'values' => ['first'] } } }

      expect(values_for('POST', field_options: empty)).to eq([{ 'note' => ['first'] }, { 'note' => ['second'] }])
    end

    # The save refuses an empty UTF-16 group number, but Ruby says that it equals ''.
    it 'gives a submitted instance with an empty UTF-16 group number after the other instances' do
      utf16 = { '0' => { 'note' => { 'group_number' => ''.encode('UTF-16LE'), 'values' => ['invalid'] } },
                '1' => { 'note' => { 'group_number' => '1', 'values' => ['valid'] } } }

      expect(values_for('POST', field_options: utf16)).to eq([{ 'note' => ['valid'] }, { 'note' => ['invalid'] }])
    end
  end

  describe '#cama_form_field_group_numbers' do
    init_site

    let(:group) do
      @site.custom_field_groups.create!(name: 'Notes', slug: '_notes', object_class: 'Site', objectid: @site.id,
                                        is_repeat: true)
    end

    before do
      group.add_manual_field({ 'name' => 'Note', 'slug' => 'note' }, { 'field_key' => 'text_box' })
      group.add_manual_field({ 'name' => 'Color', 'slug' => 'color' }, { 'field_key' => 'text_box' })
    end

    def numbers_for(verb, params = {})
      helper.request.request_method = verb
      controller.params = ActionController::Parameters.new(params)
      helper.cama_form_field_group_numbers(@site, %w[note color])
    end

    it 'gives the stored group numbers of the fields of the group for a GET request' do
      @site.set_field_value('note', 'one', group_number: 1)
      @site.set_field_value('color', 'red', group_number: 1)
      @site.set_field_value('color', 'blue', group_number: 3)

      expect(numbers_for('GET')).to eq([1, 3])
      expect(helper.cama_form_field_values(@site, %w[note color]).size).to eq(2)
    end

    # The default scope sorts the rows by their order first. Code can store the values of a lower
    # group number with a higher order.
    it 'gives the stored group numbers in ascending order, also when code stores a higher order' do
      @site.set_field_value('note', 'three', group_number: 3)
      @site.set_field_value('note', 'two', group_number: 2, order: 4)

      expect(numbers_for('GET')).to eq([2, 3])
    end

    it 'gives no group number for a record with no stored value' do
      expect(numbers_for('GET')).to eq([])
    end

    # The custom-fields partial calls the private helper once for the values and the numbers.
    it 'reads the stored values and their group numbers with one query for the partial' do
      @site.set_field_value('note', 'one', group_number: 1)
      @site.set_field_value('color', 'blue', group_number: 3)
      helper.request.request_method = 'GET'

      instances = nil
      queries = sql_queries(matching: /custom_fields_relationships/) do
        instances = helper.send(:cama_form_field_instances, @site, %w[note color], :field_options)
      end

      expect(instances).to eq([[1, { 'note' => ['one'] }], [3, { 'color' => ['blue'] }]])
      expect(queries.size).to eq(1)
    end

    it 'gives the submitted group numbers in the order of the submitted values, with nil for an invalid number' do
      submitted = { '0' => { 'note' => { 'group_number' => '3', 'values' => ['three'] } },
                    '1' => { 'note' => { 'group_number' => '1', 'values' => ['one'] } },
                    '2' => { 'note' => { 'group_number' => 'x', 'values' => ['invalid'] } } }

      expect(numbers_for('POST', field_options: submitted)).to eq([1, 3, nil])
      expect(helper.cama_form_field_values(@site, %w[note color]))
        .to eq([{ 'note' => ['one'] }, { 'note' => ['three'] }, { 'note' => ['invalid'] }])
    end
  end

  describe '#cama_form_submitted_values?' do
    # With no field_name, the helper reads its default param.
    def submitted_for(verb, params = {}, *field_name)
      helper.request.request_method = verb
      controller.params = ActionController::Parameters.new(params)
      helper.cama_form_submitted_values?(*field_name)
    end

    let(:submitted) { { '0' => { 'note' => { 'values' => ['typed'] } } } }

    it 'is false for a GET request with field values' do
      expect(submitted_for('GET', field_options: submitted)).to be(false)
    end

    it 'is true for a POST request with field values' do
      expect(submitted_for('POST', field_options: submitted)).to be(true)
    end

    it 'is false for a POST request with no field values' do
      expect(submitted_for('POST')).to be(false)
    end

    it 'reads the values under the field name that it gets' do
      expect(submitted_for('POST', theme_fields: submitted)).to be(false)
      expect(submitted_for('POST', { theme_fields: submitted }, :theme_fields)).to be(true)
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
