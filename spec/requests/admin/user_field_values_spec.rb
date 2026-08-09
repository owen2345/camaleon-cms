# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin user custom field values', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:member) { create(:user, role: 'client', site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    group = current_site.custom_field_groups.create!(
      name: 'User Fields', slug: '_user-fields', object_class: 'User', objectid: current_site.id
    )
    @color_field = group.add_manual_field({ name: 'Color', slug: 'color' }, { field_key: 'text_box' })
    sign_in_as(admin, site: current_site)
  end

  # Sibling of the widget round-trip pin: the users save asks for allowed field slugs under the
  # 'User' literal while the group's placement comes from the settings form and the read from
  # get_user_field_groups — green only while all of them agree, red on any one-sided rename.
  it 'saves a user field value through the group placed on users' do
    patch "/admin/users/#{member.id}", params: {
      user: { username: member.username, email: member.email },
      field_options: { '0' => { 'color' => { 'id' => @color_field.id.to_s, 'values' => { '0' => 'red' } } } }
    }

    expect(response).to have_http_status(:found)
    expect(member.reload.get_field_value('color')).to eq('red')
  end
end
