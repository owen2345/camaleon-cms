require 'rails_helper'
describe "Post frontend", js: true do
  before(:each) do
    @site = create(:site).decorate
    @post = @site.the_post('sample-post').decorate
  end

  it 'visit post' do
    visit @post.the_url(as_path: true)
    expect(page).to have_text(@post.the_title)
  end
  
  describe 'comments' do
    
    describe 'anonymous' do
      before(:each) do
        @post.set_meta('has_comments', '1') # enable comments for this post
        @site.set_option('permit_anonimos_comment', true) # enable anonymous comment
      end
      
      it 'anonymous comment' do
        visit @post.the_url(as_path: true)
        expect(page).to have_text('New Comment')

        within("#form-comment") do
          fill_in 'post_comment_name', :with => 'Owen'
          fill_in 'post_comment_email', :with => 'owenperedo@gmail.com'
          fill_in 'post_comment_content', :with => 'Sample comment'
        end
        click_button 'Comment'
        expect(page).to have_text('The comment has been created')
      end

      it 'anonymous comment valid captcha' do
        @site.set_option('enable_captcha_for_comments', true) # enable anonymous captcha
        Capybara.using_session("test session") do
          visit cama_captcha_path(len: 4, t: Time.current.to_i)
          captcha = page.get_rack_session['cama_captcha']
          visit @post.the_url(as_path: true)
          expect(page).to have_text('New Comment')
          within("#form-comment") do
            fill_in 'post_comment_name', :with => 'Owen'
            fill_in 'post_comment_email', :with => 'owenperedo@gmail.com'
            fill_in 'post_comment_content', :with => 'Sample comment'
            fill_in 'captcha', :with => captcha
          end
          click_button 'Comment'
          expect(page).to have_text('The comment has been created')
        end
      end

      it 'anonymous comment wrong captcha' do
        @site.set_option('enable_captcha_for_comments', true) # enable anonymous captcha
        visit @post.the_url(as_path: true)
        expect(page).to have_text('New Comment')

        within("#form-comment") do
          fill_in 'post_comment_name', :with => 'Owen'
          fill_in 'post_comment_email', :with => 'owenperedo@gmail.com'
          fill_in 'post_comment_content', :with => 'Sample comment'
        end
        click_button 'Comment'
        expect(page).not_to have_text('The comment has been created')
      end
    end

    it 'comment with user session' do
      @post.set_meta('has_comments', '1') # enable comments for this post
      admin_sign_in
      visit @post.the_url(as_path: true)
      expect(page).to have_text('New Comment')
      within("#form-comment") do
        fill_in 'post_comment_content', :with => 'Sample comment'
      end
      click_button 'Comment'
      expect(page).to have_text('The comment has been created')
    end

    it 'post not enabled for comments' do
      @post.set_meta('has_comments', '0')
      admin_sign_in
      visit @post.the_url(as_path: true)
      expect(page).not_to have_text('New Comment')
    end
  end
end