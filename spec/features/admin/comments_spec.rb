# frozen_string_literal: true

require 'rails_helper'

# add a new comment for a post
def add_new_comment
  visit "#{cama_root_relative_path}/admin/posts/#{@site.posts.last.id}/comments"
  page.execute_script('$("#comments_answer_list .panel-heading .btn-primary").click()')
  wait_for_ajax
  within 'form#new_comment' do
    fill_in 'comment_content', with: 'Test comment'
    find('button[type="submit"]').click
  end
end

describe 'the Comments', :js do
  init_site

  it 'Add Comment' do
    admin_sign_in
    add_new_comment
    expect(page).to have_css('.alert-success')
  end

  it 'list comments post' do
    admin_sign_in
    add_new_comment
    visit "#{cama_root_relative_path}/admin/comments"
    within('#admin_content') do
      # verify post presence
      expect(page).to have_content(get_content_attr('post', 'the_title', 'last').to_s)

      # access to list of comments
      first('.btn-default').click
      expect(page).to have_css('#comments_answer_list')

      # approve || disapprove comment
      first('.pending').click
      expect(page).to have_css('.alert-success')
    end

    # answer comment
    within '#comments_answer_list' do
      first('.reply').click
      wait_for_ajax
    end
    within '#new_comment' do
      fill_in 'comment_content', with: 'test answer comment'
      find('button[type="submit"]').click
    end
    expect(page).to have_css('.alert-success')
  end
end
