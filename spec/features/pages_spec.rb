require "rails_helper"
describe "the signin process", js: true do
  login_success

  it "create new page" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/7/posts/new"
    wait(2)
    screenshot_and_save_page
    within("#form-post") do
      fill_in 'post_title', :with => 'Test Title'
      page.execute_script('$("#form-post .required").val("test required value")')
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet.")')
      page.execute_script('$("#form-post #options_keywords").closest(".panel").find("a.panel-collapse").click()')
      fill_in 'options[seo_title]', :with => 'SEO Title'
      fill_in 'options[keywords]', :with => 'Test keywords changed'
      fill_in 'options[seo_description]', :with => 'Test SEO Description'
      fill_in 'options[seo_author]', :with => 'Test SEO Author'
    end
    click_button 'Create'
    expect(page).to have_css('.alert-success')
  end

  it "create edit page" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/7/posts/#{get_content_attr("page", "id", "last")}/edit"
    within("#form-post") do
      fill_in 'post_title', :with => 'Test Title changed'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet. chaged")')
    end
    click_button 'Update'
    expect(page).to have_css('.alert-success')
  end
end