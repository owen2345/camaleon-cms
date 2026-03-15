# frozen_string_literal: true

require 'rails_helper'
require_relative '../shared_specs/i18n_value_translation_safety'

RSpec.describe CamaleonCms::CustomFieldDecorator do
  let(:name) { 'Field Name' }
  let(:description) { 'Field Description' }
  let(:custom_field) { CamaleonCms::CustomField.new(name: name, description: description, object_class: 'Post') }
  let(:decorator) { described_class.new(custom_field) }

  before { I18n.backend.store_translations(:en, admin: { my_text: 'My Text', my_description: 'My Description' }) }

  describe '#the_name' do
    def render_i18n_value(value)
      custom_field.name = value
      decorator.the_name
    end

    let(:safe_input) { 't(admin.my_text)' }
    let(:expected_translation) { 'My Text' }

    it_behaves_like 'i18n value translation safety'
  end

  describe '#the_description' do
    def render_i18n_value(value)
      custom_field.description = value
      decorator.the_description
    end

    let(:safe_input) { 't(admin.my_description)' }
    let(:expected_translation) { 'My Description' }
    let(:malformed_payloads) do
      [
        "t(admin.my_description, default: 'fallback')",
        't(admin.my_description',
        't(admin.my_description)); Kernel.system(\'echo pwned\')'
      ]
    end

    it_behaves_like 'i18n value translation safety'
  end
end
