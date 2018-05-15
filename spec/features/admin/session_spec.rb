require "rails_helper"
describe "the signin process", js: true do
  init_site
  it "signs me in not valid" do
    visit "#{cama_root_relative_path}/admin/login"
    within("#login_user") do
      fill_in 'user_username', :with => 'admin'
      fill_in 'user_password', :with => 'ADMIN'
    end
    click_button 'Log In'
    expect(page).to have_css('#user_username')
  end

  it "forgot pass" do
    visit "#{cama_root_relative_path}/admin/forgot"
    within("#login_user") do
      fill_in 'user_email', :with => 'admin@local.com'
    end
    click_button 'Submit'
    expect(page).to have_content 'Send email reset success'
  end

  it "Enable Register" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/site?tab=config"
    within '#site_settings_form' do
      check "options_permit_create_account"
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
  end


  describe 'user registration' do
    before(:each) do
      @site.set_option('permit_create_account', true) # enable user registration
    end

    it "Enable Register with Captcha" do
      admin_sign_in
      visit "#{cama_root_relative_path}/admin/settings/site?tab=config"
      within '#site_settings_form' do
        check "options_security_captcha_user_register"
        click_button 'Submit'
      end
      expect(page).to have_css('.alert-success')
    end

    it "Register User" do
      visit "#{cama_root_relative_path}/admin/register"
      within("#login_user") do
        fill_in 'user[first_name]', :with => 'Name'
        fill_in 'user[last_name]', :with => 'Last Name'
        fill_in 'user[email]', :with => 'test@tester.com'
        fill_in 'user[username]', :with => 'tester'
        fill_in 'user[password]', :with => 'passsword'
        fill_in 'user[password_confirmation]', :with => 'passsword'
      end
      click_button 'Sign Up'
      expect(page).to have_css('.alert-success')
    end

    it "Register User with error in captcha" do
      @site.set_option('security_captcha_user_register', true) # enable captcha security for user registration
      visit "#{cama_root_relative_path}/admin/register"
      within("#login_user") do
        fill_in 'user[first_name]', :with => 'Name'
        fill_in 'user[last_name]', :with => 'Last Name'
        fill_in 'user[email]', :with => "test_#{Time.current.to_i}@tester.com"
        fill_in 'user[username]', :with => "tester_#{Time.current.to_i}"
        fill_in 'user[password]', :with => 'passsword'
        fill_in 'user[password_confirmation]', :with => 'passsword'
        fill_in 'captcha', :with => 'password'
      end
      click_button 'Sign Up'
      expect(page).not_to have_css('.alert-success')
    end

    it "Register User with no error in Captcha" do
      @site.set_option('security_captcha_user_register', true) # enable captcha security for user registration
      Capybara.using_session("test session") do
        visit cama_captcha_path(len: 4, t: Time.current.to_i)
        captcha = page.get_rack_session['cama_captcha']
        visit "#{cama_root_relative_path}/admin/register"
        within("#login_user") do
          fill_in 'user[first_name]', :with => 'Name'
          fill_in 'user[last_name]', :with => 'Last Name'
          fill_in 'user[email]', :with => "test_#{Time.current.to_i}@tester.com"
          fill_in 'user[username]', :with => "tester_#{Time.current.to_i}"
          fill_in 'user[password]', :with => 'passsword'
          fill_in 'user[password_confirmation]', :with => 'passsword'
          fill_in 'captcha', :with => captcha
        end
        click_button 'Sign Up'
        expect(page).to have_css('.alert-success')
      end
    end
    
  end

  
end