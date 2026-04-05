# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CustomFields create/update permissions', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    # bypass login redirect and ensure controller sees our current_site
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  context 'when updating an existing group' do
    let!(:group) do
      current_site.custom_field_groups.create!(
        name: 'Existing Group', slug: '_existing-group', object_class: 'Site', objectid: current_site.id
      )
    end

    it 'allows updating custom fields for roles with permission' do
      role = current_site.user_roles.create!(name: 'CF Manager 2', slug: 'cf_manager_2')
      role.set_meta("_manager_#{current_site.id}", { 'custom_fields' => 1 })
      user = create(:user, role: role.slug, site: current_site)
      auth_as(user)

      patch "/admin/settings/custom_fields/#{group.id}", params: {
        id: group.id,
        custom_field_group: { name: 'Existing Group Updated', assign_group: "Site,#{current_site.id}" },
        fields: { '0' => { name: 'EvalUpdate', slug: 'eval_update' } },
        field_options: { '0' => { field_key: 'select_eval' } }
      }

      expect(response).to have_http_status(302)
      expect(group.reload.fields.where(slug: 'eval_update')).to be_present
    end

    it 'blocks updating custom fields for roles without permission and sets flash error' do
      role = current_site.user_roles.create!(name: 'Limited 2', slug: 'limited_2')
      role.set_meta("_manager_#{current_site.id}", {})
      user = create(:user, role: role.slug, site: current_site)
      auth_as(user)

      patch "/admin/settings/custom_fields/#{group.id}", params: {
        id: group.id,
        custom_field_group: { name: 'Existing Group Updated 2', assign_group: "Site,#{current_site.id}" },
        fields: { '0' => { name: 'EvalBlocked', slug: 'eval_blocked' } },
        field_options: { '0' => { field_key: 'select_eval' } }
      }

      expect(response).to have_http_status(302)
      expect(group.reload.fields.where(slug: 'eval_blocked')).to be_empty
      expected_custom = I18n.t('camaleon_cms.admin.custom_field.message.select_eval_admin_only', default: 'The "Select Eval" field type is restricted to administrators.')
      expect(flash[:error]).to satisfy do |msg|
        msg = msg.to_s
        msg.include?(expected_custom) || msg.include?('You are not authorized')
      end
    end
  end

  def auth_as(user)
    # set cookie so cama_current_user can be resolved by auth token
    cookies[:auth_token] = "#{user.auth_token}&rspec&127.0.0.1"
  end

  context 'when user has the custom_fields manager permission' do
    it 'allows creating a custom field group (including select_eval fields)' do
      role = current_site.user_roles.create!(name: 'CF Manager', slug: 'cf_manager')
      role.set_meta("_manager_#{current_site.id}", { 'custom_fields' => 1 })

      user = create(:user, role: role.slug, site: current_site)
      auth_as(user)

      expect do
        post '/admin/settings/custom_fields', params: {
          custom_field_group: { name: 'Allowed Group', assign_group: "Site,#{current_site.id}" },
          # field attributes go into fields; field_key (type) is provided in field_options
          fields: { '0' => { name: 'Eval', slug: 'eval' } },
          field_options: { '0' => { field_key: 'select_eval' } }
        }
      end.to change { current_site.custom_field_groups.count }.by(1)
    end
  end

  context 'when user does NOT have the custom_fields manager permission' do
    it 'does not allow creating a custom field group containing select_eval' do
      role = current_site.user_roles.create!(name: 'Limited', slug: 'limited')
      role.set_meta("_manager_#{current_site.id}", {})

      user = create(:user, role: role.slug, site: current_site)
      auth_as(user)

      expect do
        post '/admin/settings/custom_fields', params: {
          custom_field_group: { name: 'Blocked Group', assign_group: "Site,#{current_site.id}" },
          fields: { '0' => { name: 'Eval', slug: 'eval' } },
          field_options: { '0' => { field_key: 'select_eval' } }
        }
      end.not_to(change { current_site.custom_field_groups.count })

      # should redirect (either by authorization or permission check)
      expect(response).to have_http_status(302)

      # and set an error message about select_eval restriction (either the custom message or the standard CanCan denial)
      expected_custom = I18n.t('camaleon_cms.admin.custom_field.message.select_eval_admin_only', default: 'The "Select Eval" field type is restricted to administrators.')
      expect(flash[:error]).to satisfy do |msg|
        msg = msg.to_s
        msg.include?(expected_custom) || msg.include?('You are not authorized')
      end
    end
  end
end
