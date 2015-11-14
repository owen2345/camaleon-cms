describe "the Comments", js: true do
  login_success

  it "Add Comment" do
    admin_sign_in
    visit "#{cama_root_path}/#{get_content_attr("post", "the_slug", "last")}"
    fill_in "textarea_comments", with: "Test comment"
    click_button 'Comment'
    expect(page).to have_css('.alert-success')
  end


  it "list comments post" do
    admin_sign_in
    visit "#{cama_root_path}/admin/comments"
    within("#admin_content") do
      # verify post presence
      expect(page).to have_content("#{get_content_attr("post", "the_title", "last")}")

      # access to list of comments
      first('.btn-default').click
      expect(page).to have_css('#comments_answer_list')

      # approve comment
      first('.approve').click
      expect(page).to have_css('.alert-success')
    end

    # answer comment
    first('.reply').click
    wait_for_ajax
    within "#new_comment" do
      fill_in "comment_content", with: "test answer comment"
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
  end
end