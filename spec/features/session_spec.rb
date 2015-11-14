describe "the signin process", js: true do

  login_success

  it "signs me in not valid" do
    visit "#{cama_root_path}/admin/login"
    within("#login_user") do
      fill_in 'user_username', :with => 'admin'
      fill_in 'user_password', :with => 'ADMIN'
    end
    click_button 'Log In'
    expect(page).to have_css('#user_username')
  end

  it "forgot pass" do
    visit "#{cama_root_path}/admin/forgot"
    within("#login_user") do
      fill_in 'user_email', :with => 'admin@local.com'
    end
    click_button 'Submit'
    expect(page).to have_content 'Send email reset success'
  end

  it "Enable Register" do
    visit "#{cama_root_path}/admin/settings/site?tab=config" do
      within '#site_settings_form' do
        check "meta_permit_create_account"
        click_button 'Submit'
      end
    end
    expect(page).to have_css('.alert-success')
  end


  it "Register User" do
    visit "#{cama_root_path}/admin/register"
    within("#login_user") do
      fill_in 'meta[first_name]', :with => 'Name'
      fill_in 'meta[last_name]', :with => 'Last Name'
      fill_in 'user[email]', :with => 'test@tester.com'
      fill_in 'user[username]', :with => 'tester'
      fill_in 'user[username]', :with => 'tester'
      fill_in 'user[password]', :with => 'passswor'
      fill_in 'user[password_confirmation]', :with => 'passswor'
      fill_in 'user[password_confirmation]', :with => 'passswor'
      fill_in 'captcha', :with => 'passswor'
    end
    click_button 'Sign Up'
    expect(page).to have_css('.alert-success')
  end
end