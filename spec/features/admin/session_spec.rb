# frozen_string_literal: true

describe 'the signin process', :js do
  init_site
  it 'signs me in with valid credentials' do # rubocop:disable RSpec/NoExpectationExample
    admin_form_sign_in
  end

  it 'signs me in not valid' do
    visit "#{cama_root_relative_path}/admin/login"
    within('#login_user') do
      fill_in 'user_username', with: 'admin'
      fill_in 'user_password', with: 'ADMIN'
    end
    click_button 'Log In'
    expect(page).to have_css('#user_username')
  end

  it 'forgot pass' do
    visit "#{cama_root_relative_path}/admin/forgot"
    within('#login_user') do
      fill_in 'user_email', with: 'admin@local.com'
    end
    click_button 'Submit'
    # Security (M13): one neutral message whether or not the email matched an account.
    expect(page).to have_text 'If an account matches that email, a password reset link has been sent.'
  end

  # Usernames and emails are stored downcased, so mixed-case input must keep matching
  # regardless of the database collation's case sensitivity.
  # The expectation admin_form_sign_in makes internally is invisible to the reader and to
  # RSpec/NoExpectationExample, which is why this needed a cop disable. Naming the outcome here
  # says what signing in is supposed to produce, and drops the disable.
  it 'signs me in with a mixed-case username' do
    admin_form_sign_in('Admin')

    expect(page).to have_current_path(%r{/admin/dashboard}, ignore_query: true)
  end

  it 'sends the reset email for a mixed-case address' do
    # The page answer is deliberately neutral (M13), so the proof that the mixed-case input matched
    # the downcased account is the reset stamp on the user itself.
    account = CamaleonCms::User.find_by(email: 'admin@local.com')
    expect(account.password_reset_sent_at).to be_blank

    visit "#{cama_root_relative_path}/admin/forgot"
    within('#login_user') do
      fill_in 'user_email', with: 'Admin@Local.com'
    end
    click_button 'Submit'

    expect(page).to have_text 'If an account matches that email, a password reset link has been sent.'
    expect(account.reload.password_reset_sent_at).to be_present
  end

  it 'Enable Register' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/site?tab=config"
    within '#site_settings_form' do
      check 'options_permit_create_account'
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
  end

  describe 'user registration' do
    before do
      @site.set_option('permit_create_account', true) # enable user registration
    end

    it 'Enable Register with Captcha' do
      admin_sign_in
      visit "#{cama_root_relative_path}/admin/settings/site?tab=config"
      within '#site_settings_form' do
        check 'options_security_captcha_user_register'
        click_button 'Submit'
      end
      expect(page).to have_css('.alert-success')
    end

    it 'Register User' do
      visit "#{cama_root_relative_path}/admin/register"
      within('#login_user') do
        fill_in 'user[first_name]', with: 'Name'
        fill_in 'user[last_name]', with: 'Last Name'
        fill_in 'user[email]', with: 'test@tester.com'
        fill_in 'user[username]', with: 'tester'
        fill_in 'user[password]', with: 'passsword'
        fill_in 'user[password_confirmation]', with: 'passsword'
      end
      click_button 'Sign Up'
      expect(page).to have_css('.alert-success')
    end

    it 'Register User with error in captcha' do
      @site.set_option('security_captcha_user_register', true) # enable captcha security for user registration
      visit "#{cama_root_relative_path}/admin/register"
      within('#login_user') do
        fill_in 'user[first_name]', with: 'Name'
        fill_in 'user[last_name]', with: 'Last Name'
        fill_in 'user[email]', with: "test_#{Time.current.to_i}@tester.com"
        fill_in 'user[username]', with: "tester_#{Time.current.to_i}"
        fill_in 'user[password]', with: 'passsword'
        fill_in 'user[password_confirmation]', with: 'passsword'
        fill_in 'captcha', with: 'password'
      end
      click_button 'Sign Up'
      expect(page).to have_no_css('.alert-success')
    end

    # The happy path — a correct captcha registers a legitimate user — is covered deterministically in
    # spec/requests/security/captcha_hardening_spec.rb. It cannot be exercised reliably here: a captcha
    # is now single-use and bound to the one challenge the register page issues, while get_rack_session
    # navigates away to read it and each register render issues a fresh challenge, so the browser can
    # never both read the current answer and submit against it.
  end
end
