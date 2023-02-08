require 'rails_helper'

describe 'the Site Settings SideBar options', js: true do
  init_site

  before { admin_sign_in }

  describe 'General Site settings form' do
    let(:new_site_domain) { 'New_site_domain' }

    it 'is capturing main site options in the Settings Form' do
      visit "#{cama_root_relative_path}/admin/settings/site"
      expect(page).to have_content('Basic Information')
      expect(page).to have_content('Configuration')
      within '#site_settings_form' do
        fill_in 'site_name', with: 'New site title'
        fill_in 'site_description', with: 'Site description'
        click_button 'Submit'
      end
      expect(page).to have_css('.alert-success')
    end

    it 'is redirecting to the new site domain' do
      visit "#{cama_root_relative_path}/admin/settings/site"
      within '#site_settings_form' do
        fill_in 'site_slug', with: new_site_domain
        click_button 'Submit'
      end
      expect(URI.parse(current_url).host).to eql(new_site_domain.downcase)
    end
  end

  describe 'Theme settings form' do
    let(:added_text) { ' Add some text' }

    it 'has a Tiny MCE form' do
      visit "#{cama_root_relative_path}/admin/settings/theme"

      expect(page).to have_content('Footer message')
      expect(webfont_icon_fetch_status('fa fa-cog', 'fontawesome-webfont', 'woff2')).to be(200)

      within '#theme_settings_form' do
        within '.mce-edit-area' do
          within_frame do
            editor = page.find_by_id('tinymce')
            expect(editor.text).to eql('Copyright © 2015 - Camaleon CMS. All rights reservated.')
            editor.native.send_keys(added_text)
          end
        end

        click_button 'Submit'
      end

      within '.mce-edit-area' do
        within_frame do
          editor = page.find_by_id('tinymce')
          expect(editor.text).to eql("Copyright © 2015 - Camaleon CMS. All rights reservated.#{added_text}")
        end
      end
    end
  end
end
