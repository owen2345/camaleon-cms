# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'camaleon_cms/admin/settings/custom_fields/_get_items.html.erb', type: :view do
  let(:field_elements) do
    {
      text_box: {
        key: 'text_box',
        label: 'Text Box',
        extra_fields: [],
        options: {}
      }
    }
  end

  before do
    allow(view).to receive(:cama_custom_field_elements).and_return(field_elements)
    assign(:item_value, { id: '99', name: 'Sample' })
    assign(:item_options_value, options)
  end

  def render_partial
    render partial: 'camaleon_cms/admin/settings/custom_fields/get_items'
  end

  context 'when the field options have a valid field_key' do
    let(:options) { { 'field_key' => 'text_box' } }

    before { assign(:key, 'text_box') }

    it 'renders the field panel without errors' do
      render_partial
      expect(rendered).to include('panel-item')
    end
  end

  context 'when the field options are legacy/orphaned and have no field_key (@key is nil)' do
    let(:options) { { 'not_deleted' => true } }

    before { assign(:key, nil) }

    it 'does not raise and renders no field panel' do
      expect { render_partial }.not_to raise_error
      expect(rendered).not_to include('panel-item')
    end
  end
end
