require "rails_helper"
describe "the Content Groups", js: true do
  login_success

  it "create new content group" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/post_types"
    expect(page).to have_content('Post')
    expect(page).to have_content('Page')
    within("#post_type_form") do
      fill_in 'post_type_name', :with => 'Test cat'
      fill_in 'post_type_slug', :with => 'test-content'
      fill_in 'post_type_description', :with => 'test-content descri'
      check("Manage Category")
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
  end

  it "edit content type" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/post_types"
    within '#admin_content' do
      all("table .btn-default").last.click
    end
    within("#post_type_form") do
      expect(page).to have_checked_field("Manage Category")
      fill_in 'post_type_name', :with => 'Test cat updated'
      fill_in 'post_type_slug', :with => 'test-content'
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
  end

  it "delete content type" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/post_types"
    within '#admin_content' do
      all("table .btn-danger").last.click
    end
    confirm_dialog
    expect(page).to have_css('.alert-success')
  end

end