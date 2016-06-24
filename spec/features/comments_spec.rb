require "rails_helper"
describe "the Comments", js: true do
  login_success

  it "Add Comment" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/posts/#{get_content_attr("post", "id", "last")}/comments"
    page.execute_script('$("#comments_answer_list .panel-heading .btn-primary").click()')
    wait_for_ajax
    within 'form#new_comment' do
      fill_in "comment_content", with: "Test comment"
      find('button[type="submit"]').click
    end
    expect(page).to have_css('.alert-success')
  end


  it "list comments post" do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/comments"
    within("#admin_content") do
      # verify post presence
      expect(page).to have_content("#{get_content_attr("post", "the_title", "last")}")

      # access to list of comments
      first('.btn-default').click
      expect(page).to have_css('#comments_answer_list')

      # approve || disapprove comment
      (first('.approve') || first('.pending')).click
      expect(page).to have_css('.alert-success')
    end

    # answer comment
    within '#comments_answer_list' do
      first('.reply').click
      wait_for_ajax
    end
    within "#new_comment" do
      fill_in "comment_content", with: "test answer comment"
      find('button[type="submit"]').click
    end
    expect(page).to have_css('.alert-success')
  end
end