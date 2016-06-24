require "rails_helper"
describe "the signin process", js: true do
  login_success

  it "create new category" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/2/categories"
    within("#form-category") do
      fill_in 'category_name', :with => 'Test cat'
      fill_in 'category_slug', :with => 'test-cat'
    end
    click_button 'Submit'
    expect(page).to have_css('.alert-success')
  end

  it "create edit category" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/2/categories/6/edit"
    within("#form-category") do
      fill_in 'category_name', :with => 'Test cat update'
    end
    click_button 'Submit'
    expect(page).to have_css('.alert-success')
  end
end