# frozen_string_literal: true

require 'rails_helper'

def create_site
  visit "#{cama_root_relative_path}/admin/settings/sites"
  expect(page).to have_content('List Sites')

  within '#admin_content' do
    click_link 'Add Site'
  end
  expect(page).to have_css('#new_site')
  within '#new_site' do
    fill_in 'site_slug', with: 'owen'
    fill_in 'site_name', with: 'Owen sub site'
    click_button 'Submit'
  end
end

describe 'the Sites', :js do
  init_site

  it 'Sites list' do
    admin_sign_in
    create_site
    expect(page).to have_css('.alert-success')
  end

  it 'Site Edit' do
    admin_sign_in
    create_site
    visit "#{cama_root_relative_path}/admin/settings/sites"
    within '#admin_content' do
      all('.btn-default').last.click
    end
    within '#edit_site' do
      fill_in 'site_name', with: 'Owen Site Title changed'
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
  end

  it 'Site destroy' do
    admin_sign_in
    create_site
    visit "#{cama_root_relative_path}/admin/settings/sites"
    within '#admin_content' do
      all('.btn-danger').last.click
    end
    confirm_dialog
    expect(page).to have_css('.alert-success')
  end

  describe 'Sites mass assignment protection' do
    it 'site_params only permits name, slug, description' do
      controller = CamaleonCms::Admin::Settings::SitesController.new
      params = ActionController::Parameters.new(
        site: {
          name: 'Test Site',
          slug: 'test-slug',
          description: 'Test description',
          term_group: 999,
          parent_id: 999,
          user_id: 999
        }
      )
      allow(controller).to receive(:params).and_return(params)

      permitted = controller.send(:site_params).permit!

      expect(permitted.to_h.keys).to match_array(%w[name slug description])
      expect(permitted['term_group']).to be_nil
      expect(permitted['parent_id']).to be_nil
      expect(permitted['user_id']).to be_nil
    end
  end

  it 'redirects to safe admin path instead of site URL after main site slug change' do
    main_site = CamaleonCms::Site.first
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/sites/#{main_site.id}/edit"
    fill_in 'site_slug', with: "#{main_site.slug}-updated"
    click_button 'Submit'
    expect(current_path).not_to eq("/#{main_site.slug}")
  end
end
