require "rails_helper"
describe "the User Roles", js: true do
  login_success

  it "User Roles list" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/user_roles"
    expect(page).to have_content("User Roles")
    expect(page).to have_content("Administrator")
    expect(page).to have_content("Editor")
    expect(page).to have_content("Contributor")

    # create user role
    within '#admin_content' do
      click_link "Add User Role"
    end
    expect(page).to have_css("#new_user_role")
    within '#new_user_role' do
      fill_in "user_role_name", with: 'Test Role'
      fill_in "user_role_slug", with: 'tester-role'
      fill_in "user_role_description", with: 'tester descr'
      check "Comments"
      check "Themes"
      click_button "Submit"
    end
    expect(page).to have_css('.alert-success')
  end

  # TODO verification of all roles
  # it "Users Verify Role" do
  #   admin_sign_in(false, "tester", "tester")
  # end

  it "User Role Edit" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/user_roles"
    within '#admin_content' do
      all(".btn-default").last.click
    end
    expect(page).to have_checked_field("Themes")
    within '#edit_user_role' do
      fill_in "user_role_name", with: 'Test Role updated'
      fill_in "user_role_slug", with: 'tester-role-updated'
      fill_in "user_role_description", with: 'tester descr updated'
      check "Settings"
      click_button "Submit"
    end
    expect(page).to have_css('.alert-success')
  end

  it "User Group destroy" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/user_roles"
    within '#admin_content' do
      all(".btn-danger").last.click
    end
    confirm_dialog
    expect(page).to have_css('.alert-success')
  end
end