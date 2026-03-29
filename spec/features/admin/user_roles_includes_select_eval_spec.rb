require 'rails_helper'

describe 'User Roles UI includes select_eval permission', :js do
  init_site

  it 'shows a select_eval checkbox in the manager permissions when creating a role' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/user_roles"
    within '#admin_content' do
      click_link 'Add User Role'
    end
    expect(page).to have_css('#new_user_role')
    within '#new_user_role' do
      # ensure the checkbox for Select Eval exists
      expect(page).to have_unchecked_field('Select Eval')
    end
  end
end
