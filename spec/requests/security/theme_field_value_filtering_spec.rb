# frozen_string_literal: true

require 'rails_helper'

# save_theme wrote two custom-field payloads straight into set_field_values without the 2.9.2
# allowed-slugs filter every sibling admin save uses: the `theme_fields` param, and the
# `field_options` the bundled `new` theme's on_theme_settings hook re-saved raw (its redirect to
# a non-existent route also errored after that write). Both now route through the filter, and the
# bundled hook no longer saves at all -- save_theme persists field_options generically. The
# surface is a grantable role capability (`:manage, :theme_settings`), reachable by non-admin
# roles.
RSpec.describe 'Theme settings field-value filtering', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:theme_role) { current_site.user_roles.create!(name: 'Theme Manager', slug: 'theme_mgr') }
  let(:editor) { create(:user, role: theme_role.slug, site: current_site) }
  let(:theme) { current_site.get_theme }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    theme_role.set_meta("_manager_#{current_site.id}", { 'theme_settings' => 1 })
    group = theme.add_field_group({ name: 'Theme Fields', slug: '_theme-fields' })
    @bg_field = group.add_manual_field({ name: 'Background', slug: 'bg_color' }, { field_key: 'text_box' })
    sign_in_as(editor, site: current_site)
  end

  def relationship_count(slug)
    CamaleonCms::CustomFieldsRelationship.where(custom_field_slug: slug).count
  end

  describe 'the theme_fields payload' do
    it 'drops values for a slug not registered on the theme' do
      post '/admin/settings/save_theme', params: {
        theme_fields: { '0' => { 'evil' => { 'id' => @bg_field.id.to_s, 'values' => { '0' => 'x' } } } }
      }

      expect(relationship_count('evil')).to eq(0)
    end

    it 'saves values for a registered slug' do
      post '/admin/settings/save_theme', params: {
        theme_fields: { '0' => { 'bg_color' => { 'id' => @bg_field.id.to_s, 'values' => { '0' => 'blue' } } } }
      }

      expect(theme.get_field_value('bg_color')).to eq('blue')
    end
  end

  describe 'a save with the bundled new theme active' do
    let(:theme) { current_site.get_theme('new') }

    before { current_site.set_option('_theme', 'new') }

    it 'drops values for an unregistered slug and answers with a single redirect' do
      post '/admin/settings/save_theme', params: {
        action_name: 'save_settings',
        field_options: { '0' => { 'evil' => { 'id' => @bg_field.id.to_s, 'values' => { '0' => 'x' } } } }
      }

      expect(response).to have_http_status(:found)
      expect(relationship_count('evil')).to eq(0)
    end

    it 'saves a registered slug and answers with a single redirect' do
      registered = theme.add_field_group({ name: 'New Theme Fields', slug: '_new-theme-fields' })
                        .add_manual_field({ name: 'Footer', slug: 'footer_text' }, { field_key: 'text_box' })

      post '/admin/settings/save_theme', params: {
        action_name: 'save_settings',
        field_options: { '0' => { 'footer_text' => { 'id' => registered.id.to_s, 'values' => { '0' => 'hi' } } } }
      }

      expect(response).to have_http_status(:found)
      expect(theme.get_field_value('footer_text')).to eq('hi')
    end
  end

  # A submission whose slugs are all unregistered filters to an empty payload. set_field_values
  # deletes every existing value before writing, so an empty-but-present payload must not reach
  # it, or a save carrying no registered slug wipes the object's stored values.
  describe 'a submission carrying no registered slug' do
    before { theme.save_field_value('bg_color', 'keep') }

    it 'leaves existing values intact on the field_options path' do
      post '/admin/settings/save_theme', params: {
        field_options: { '0' => { 'evil' => { 'id' => @bg_field.id.to_s, 'values' => { '0' => 'x' } } } }
      }

      expect(theme.get_field_value('bg_color')).to eq('keep')
    end

    it 'leaves existing values intact on the theme_fields path' do
      post '/admin/settings/save_theme', params: {
        theme_fields: { '0' => { 'evil' => { 'id' => @bg_field.id.to_s, 'values' => { '0' => 'x' } } } }
      }

      expect(theme.get_field_value('bg_color')).to eq('keep')
    end
  end
end
