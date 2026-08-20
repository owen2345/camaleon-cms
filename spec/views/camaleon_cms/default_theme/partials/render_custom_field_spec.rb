# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'camaleon_cms/default_theme/partials/_render_custom_field', type: :view do
  let(:field_name) { 'Field Name' }
  let(:fields) do
    { secure_checkbox: { name: field_name, values: 'checked', options: { field_key: 'checkbox', translate: false } } }
  end

  before { I18n.backend.store_translations(:en, admin: { my_text: 'My Text' }) }

  def rendered_label
    Nokogiri::HTML.fragment(rendered).at_css('strong').text
  end

  it 'renders translated labels for safe t(...) keys' do
    render partial: 'camaleon_cms/default_theme/partials/render_custom_field',
           locals: { fields: fields.deep_dup.tap { |h| h[:secure_checkbox][:name] = 't(admin.my_text)' } }

    expect(rendered_label).to eq('My Text')
  end

  it 'does not execute Ruby code from malicious t(...) payloads' do
    payload = "t(Kernel.system('echo pwned'))"

    expect(Kernel).not_to receive(:system)
    render partial: 'camaleon_cms/default_theme/partials/render_custom_field',
           locals: { fields: fields.deep_dup.tap { |h| h[:secure_checkbox][:name] = payload } }

    expect(rendered_label).to eq(payload)
  end
end
