# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin widget assigned field values', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:widget) { current_site.widgets.create!(name: 'Field Widget', slug: 'field-widget') }
  let(:sidebar) { current_site.sidebars.create!(name: 'Probe Sidebar', slug: 'probe-sidebar') }
  let(:assigned) { sidebar.assigned.create!(title: 'Default', widget_id: widget.id) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    group = widget.add_custom_field_group(name: 'Widget Fields', slug: 'widget-fields')
    @color_field = group.add_manual_field({ name: 'Color', slug: 'color' }, { field_key: 'text_box' })
    sign_in_as(admin, site: current_site)
  end

  # The 2.8.x–2.9.2 widget custom-fields breakage was exactly this joint: the assign save asked
  # for allowed field slugs under one scope name while the widget's group was stored under
  # another, so submitted values were silently discarded. Green means the controller's scope
  # literal and the association scope agree end to end.
  it 'saves an assigned-widget field value through the group placed on the widget' do
    patch "/admin/appearances/widgets/sidebar/#{sidebar.id}/assign/#{assigned.id}", params: {
      assign: { title: 'Default' },
      field_options: { '0' => { 'color' => { 'id' => @color_field.id.to_s, 'values' => { '0' => 'red' } } } }
    }

    expect(response).to have_http_status(:found)
    expect(assigned.reload.get_field_value('color')).to eq('red')
  end
end
