require "rails_helper"

# create a new post tag
def create_tag
  visit "#{cama_root_relative_path}/admin/post_type/2/post_tags"
  within("#new_post_tag") do
    fill_in 'post_tag_name', :with => 'Test tag'
    fill_in 'post_tag_slug', :with => 'test-tag'
  end
  click_button 'Submit'
end

describe "the signin process", js: true do
  init_site

  it "create new tag" do
    admin_sign_in
    create_tag
    expect(page).to have_css('.alert-success')
  end

  it "create edit tag" do
    admin_sign_in
    create_tag
    within '.page-content-wrap' do
      all(".btn_edit").last.click
    end
    within("#edit_post_tag") do
      fill_in 'post_tag_name', :with => 'Test tag update'
    end
    click_button 'Submit'
    expect(page).to have_css('.alert-success')
  end
end