# frozen_string_literal: true

require 'rails_helper'

# Reproduces the reported symptom of https://github.com/owen2345/camaleon-cms/issues/1124:
# a required field belonging to another content type is rendered on the site settings form with
# `class="required"`, so jQuery validation refuses to submit until it is filled in. The block is
# client-side, which is why it needs a :js feature spec rather than a request spec.
describe 'Site settings with custom field groups of other content types', :js do
  init_site

  before do
    group = @site.custom_field_groups.create!(
      name: 'Post Type Group', slug: '_post-type-group',
      object_class: 'PostType_Post', objectid: @site.post_types.first.id
    )
    group.add_field({ 'name' => 'Post Type Field', 'slug' => 'post_type_field' },
                    { 'field_key' => 'text_box', 'required' => '1' })
    admin_sign_in
  end

  it 'saves the site settings without asking for the unrelated required field' do
    visit "#{cama_root_relative_path}/admin/settings/site"

    within '#site_settings_form' do
      fill_in 'site_name', with: 'New site title'
      click_button 'Submit'
    end

    expect(page).to have_css('.alert-success')
    expect(@site.reload.name).to eql('New site title')
  end
end
