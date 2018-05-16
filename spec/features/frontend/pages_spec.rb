require 'rails_helper'
include CamaleonCms::PluginsHelper
describe "Post frontend", js: true do
  init_site

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
  
  describe 'post visibility' do
    before(:each) do
      current_site(@site)
      plugin_install('visibility_post')
    end
    
    it 'public post' do
      custom_post = create(:post, site: @site).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_http_status(:success)
    end

    it 'public future post with login' do
      custom_post = create(:post, site: @site, published_at: 1.day.from_now).decorate
      admin_sign_in(custom_post.owner.username, '12345678')
      visit custom_post.the_url(as_path: true)
      expect(page).to have_http_status(:not_found)
    end

    it 'public future post without login' do
      custom_post = create(:post, site: @site, published_at: 1.day.from_now).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_http_status(:not_found)
    end

    it 'private post without login ' do
      custom_post = create(:private_post, site: @site).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_http_status(:not_found)
    end

    it 'private post with login' do
      user = create(:user, password: '12345678', password_confirmation: '12345678', site: @site)
      custom_post = create(:private_post, site: @site, owner: user).decorate
      admin_sign_in(user.username, '12345678')
      visit custom_post.the_url(as_path: true)
      expect(page).to have_http_status(:success)
    end

    it 'password post without password ' do
      custom_post = create(:password_post, site: @site).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_text('Enter the password:')
    end

    it 'password post with password ' do
      custom_post = create(:password_post, site: @site).decorate
      visit custom_post.the_url(as_path: true, post_password: custom_post.visibility_value)
      expect(page).to have_http_status(:success)
    end
  end
end