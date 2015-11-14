describe "the signin process", js: true do
  login_success

  it "create new page" do
    admin_sign_in
    visit "#{cama_root_path}/admin/post_type/7/posts/new"
    within("#form-post") do
      fill_in 'post_title', :with => 'Test Title'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet.")')
      fill_in 'post_keywords', :with => 'test keywords'
    end
    click_button 'Create'
    expect(page).to have_css('.alert-success')
  end

  it "create edit page" do
    admin_sign_in
    visit "#{cama_root_path}/admin/post_type/7/posts/#{get_content_attr("page", "id", "last")}/edit"
    within("#form-post") do
      fill_in 'post_title', :with => 'Test Title changed'
      page.execute_script('$("#form-post .tinymce_textarea").tinymce().setContent("Pants are pretty sweet. chaged")')
      fill_in 'post_keywords', :with => 'test keywords changed'
    end
    click_button 'Update'
    expect(page).to have_css('.alert-success')
  end
end