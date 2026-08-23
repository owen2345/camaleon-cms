# frozen_string_literal: true

describe 'no found', :js do
  init_site

  it '404s' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/nothing-here"
    expect(page).to have_text('Invalid route')
  end
end
