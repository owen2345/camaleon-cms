# frozen_string_literal: true

require 'rails_helper'

# Security (scan-and-reject policy): a `field_attrs` value is gated at save
# (CustomFieldsRelationship scans the decoded JSON members), so the partial renders the stored
# attr/value pair verbatim -- stored values always equal authored values. This spec pins the
# verbatim contract and the bugfix that the pair's VALUE is rendered (the old line printed the
# attribute name twice and never the value).
RSpec.describe 'camaleon_cms/default_theme/partials/_render_custom_field', type: :view do
  def render_field_attrs(value)
    fields = {
      'specs' => { name: 'Specs', options: { field_key: 'field_attrs', translate: false }, values: value }
    }
    render partial: 'camaleon_cms/default_theme/partials/render_custom_field', locals: { fields: fields }
  end

  it 'renders the stored attribute name and value verbatim' do
    render_field_attrs({ attr: 'Color', value: 'Deep <em>red</em>' }.to_json)

    expect(rendered).to include('<strong>Color: </strong>Deep <em>red</em>')
  end

  it 'renders the value, not the attribute name twice' do
    render_field_attrs({ attr: 'Size', value: 'XL' }.to_json)

    expect(rendered).to include('<strong>Size: </strong>XL')
    expect(rendered).not_to include('<strong>Size: </strong>Size')
  end

  it 'renders no pair for an unparseable stored value' do
    render_field_attrs('not json')

    expect(rendered).not_to include('<p><strong>')
    expect(rendered).not_to include('not json')
  end

  # Audit M6: a valid JSON value that is not an object (array/scalar) must render nothing instead of
  # raising a TypeError (Array#[] with a String key) and 500ing the public page.
  it 'renders no pair (and does not raise) for a JSON array value' do
    expect { render_field_attrs([{ attr: 'a', value: 'b' }].to_json) }.not_to raise_error
    expect(rendered).not_to include('<p><strong>')
  end
end
