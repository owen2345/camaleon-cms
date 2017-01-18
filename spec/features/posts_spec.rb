require "rails_helper"
describe "the signin process", js: true do
  login_success

  it "create new post" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/2/posts/new"
    within("#form-post") do
      fill_in 'post_title', :with => 'Test Title'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet.")')
      page.execute_script('$("#form-post input[name=\'categories[]\']:first").prop("checked", true)')
      wait(2)
      fill_in 'post_summary', :with => 'test summary'
      page.execute_script("$('#form-post input[name=\"tags\"]').val('owen,dota')")
    end
    click_button 'Create'
    expect(page).to have_css('.alert-success')
  end

  it "create edit post" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/2/posts/#{get_content_attr("post", "id", "last")}/edit"
    within("#form-post") do
      fill_in 'post_title', :with => 'Test Title changed'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet. chaged")')
      fill_in 'post_summary', :with => 'test summary changed'
    end
    click_button 'Update'
    expect(page).to have_css('.alert-success')
    # visit page in frontend
    visit "#{get_content_attr("post", "the_path", "last")}"
    expect(page).to have_content("Test Title changed")
  end
end