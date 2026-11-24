# frozen_string_literal: true

RSpec.describe 'the reset of the browser after an example', :js do
  init_site

  before do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/dashboard"
    assert_current_path(%r{/admin/dashboard}, ignore_query: true)
    page.execute_script("localStorage.setItem('cama_reset_probe', '1')")

    # Capybara runs this reset after each example.
    Capybara.reset_sessions!
  end

  it 'signs the admin out' do
    visit "#{cama_root_relative_path}/admin/dashboard"

    expect(page).to have_current_path(%r{/admin/login}, ignore_query: true)
  end

  it 'removes the local storage of the admin pages' do
    visit "#{cama_root_relative_path}/admin/login"

    expect(page.evaluate_script("localStorage.getItem('cama_reset_probe')")).to be_nil
  end
end
