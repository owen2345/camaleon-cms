require "rails_helper"
describe "the Users", js: true do
  login_success
  uname = "testerr_#{Time.current.to_i}"
  uemail = "testerr_#{Time.current.to_i}@gmail.com"
  it "Users list" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/users"
    expect(page).to have_content("List Users")

    # create user
    within '#admin_content' do
      click_link "Add User"
    end
    expect(page).to have_content("Create User")
    within '#user_form' do
      fill_in "user[first_name]", with: 'Test'
      fill_in "user[last_name]", with: 'Test Last name'
      fill_in "meta[slogan]", with: 'My slogan'
      fill_in "user[username]", with: uname
      fill_in "user[email]", with: uemail
      fill_in "user[password]", with: 'tester123'
      fill_in "user[password_confirmation]", with: 'tester123'
      find(".user-form-left").click_button "Create"
    end
    screenshot_and_save_page
    expect(page).to have_css('.alert-success')
    expect(page).to have_content("tester")
  end

  it "Users login new user" do
    admin_sign_in(false, uname, "tester123")
  end

  it "Users Edit" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/users"
    within '#admin_content' do
      all(".btn-default")[1].click
    end
    within '#user_form' do
      fill_in "user[first_name]", with: 'Test updated'
      fill_in "user[last_name]", with: 'Test Last name udpated'
      fill_in "meta[slogan]", with: 'My slogan updated'
      fill_in "user[username]", with: 'tester-updated'
      fill_in "user[email]", with: 'tester_updated@gmail.com'
      find(".user-form-left").click_button "Update"
    end
    # wait(30)
    expect(page).to have_css('.alert-success')
  end

  it "Users Update Pass" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/users"
    within '#admin_content' do
      all(".btn-default")[1].click
    end
    within '#user_form' do
      click_link "Change Password"
    end
    wait_for_ajax
    within '#profie-form-ajax-password' do
      fill_in 'password[password]', with: "tester_new"
      fill_in 'password[password_confirmation]', with: "tester_new"
      click_button "Proccess"
    end
    wait_for_ajax
    expect(page).to have_css('.alert-success')
  end

  it "Users destroy" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/users"
    within '#admin_content' do
      all(".btn-danger")[1].click
    end
    confirm_dialog
    expect(page).to have_css('.alert-success')
  end
end