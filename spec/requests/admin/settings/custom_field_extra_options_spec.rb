# frozen_string_literal: true

# Saving a custom field group must persist the per-kind extra options the settings UI offers.
# The permit list allowed only :dimension of them, so Color Format, date type, file formats,
# image versions, the posts-field post-type filter and the panel collapse state were silently
# stripped on every save - and, because saving replaces the field's whole options meta, a
# re-save also wiped any previously stored value.
RSpec.describe 'saving custom field extra options', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:post_type) { current_site.post_types.where(slug: 'post').first }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  it 'persists every extra option the field settings panels offer' do
    post '/admin/settings/custom_fields', params: {
      custom_field_group: { name: 'Style options', assign_group: "PostType,#{post_type.id}" },
      fields: {
        '0' => { name: 'Tint', slug: 'tint' },
        '1' => { name: 'Cover', slug: 'cover' },
        '2' => { name: 'Due', slug: 'due' },
        '3' => { name: 'Related', slug: 'related' }
      },
      field_options: {
        '0' => { field_key: 'colorpicker', color_format: 'rgba', panel_hidden: '1' },
        '1' => { field_key: 'image', dimension: '640x480', versions: '100x100' },
        '2' => { field_key: 'date', type_date: '1' },
        '3' => { field_key: 'posts', post_types: [post_type.id.to_s] }
      }
    }

    group = current_site.custom_field_groups.find_by!(name: 'Style options')
    expect(group.fields.find_by!(slug: 'tint').options).to include(color_format: 'rgba', panel_hidden: '1')
    expect(group.fields.find_by!(slug: 'cover').options).to include(dimension: '640x480', versions: '100x100')
    expect(group.fields.find_by!(slug: 'due').options).to include(type_date: '1')
    expect(group.fields.find_by!(slug: 'related').options[:post_types]).to eq([post_type.id.to_s])
  end
end
