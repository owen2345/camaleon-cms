require "rails_helper"
describe "the signin process", js: true do
  login_success

  it "create new tag" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/2/post_tags"
    within("#new_post_tag") do
      fill_in 'post_tag_name', :with => 'Test tag'
      fill_in 'post_tag_slug', :with => 'test-tag'
    end
    click_button 'Submit'
    expect(page).to have_css('.alert-success')
  end

  it "create edit tag" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/2/post_tags/#{get_tag_attr("id", "last")}/edit"
    within("#edit_post_tag") do
      fill_in 'post_tag_name', :with => 'Test tag update'
    end
    click_button 'Submit'
    expect(page).to have_css('.alert-success')
  end
end