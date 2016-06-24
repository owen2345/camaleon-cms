require "rails_helper"
describe "the Site Settings", js: true do
  login_success

  it "Settings Form" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/site"
    expect(page).to have_content("Basic Information")
    expect(page).to have_content("Configuration")
    within '#site_settings_form' do
      fill_in "site_name", with: 'New site title'
      fill_in "site_description", with: 'Site description'
      click_button "Submit"
    end
    expect(page).to have_css('.alert-success')
  end
end