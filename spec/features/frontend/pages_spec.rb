# frozen_string_literal: true

require 'rails_helper'

include CamaleonCms::PluginsHelper

RSpec.describe 'Post frontend', :js do
  init_site

  it 'visit post' do
    visit @post.the_url(as_path: true)
    expect(page).to have_text(@post.the_title)
  end

  describe 'comments' do
    describe 'anonymous' do
      before do
        @post.set_meta('has_comments', '1') # enable comments for this post
        @site.set_option('permit_anonimos_comment', true) # enable anonymous comment
      end

      it 'anonymous comment' do
        visit @post.the_url(as_path: true)
        expect(page).to have_text('New Comment')

        within('#form-comment') do
          fill_in 'post_comment_name', with: 'Owen'
          fill_in 'post_comment_email', with: 'owenperedo@gmail.com'
          fill_in 'post_comment_content', with: 'Sample comment'
        end
        click_button 'Comment'
        expect(page).to have_text('The comment has been created')
      end

      # The happy path — a correct captcha lets the anonymous comment through — is covered
      # deterministically in spec/requests/security/captcha_hardening_spec.rb. It cannot be
      # exercised reliably here: a captcha is now single-use and bound to the one challenge the
      # rendered page issues, while get_rack_session navigates away to read it and each post-page
      # render fetches a fresh captcha image, so the browser can never both read the current
      # answer and submit against it.

      it 'anonymous comment wrong captcha' do
        @site.set_option('enable_captcha_for_comments', true) # enable anonymous captcha
        visit @post.the_url(as_path: true)
        expect(page).to have_text('New Comment')

        within('#form-comment') do
          fill_in 'post_comment_name', with: 'Owen'
          fill_in 'post_comment_email', with: 'owenperedo@gmail.com'
          fill_in 'post_comment_content', with: 'Sample comment'
        end
        click_button 'Comment'
        expect(page).to have_no_text('The comment has been created')
      end
    end

    it 'comment with user session' do
      @post.set_meta('has_comments', '1') # enable comments for this post
      admin_sign_in
      visit @post.the_url(as_path: true)
      expect(page).to have_text('New Comment')
      within('#form-comment') do
        fill_in 'post_comment_content', with: 'Sample comment'
      end
      click_button 'Comment'
      expect(page).to have_text('The comment has been created')
    end

    it 'post not enabled for comments' do
      @post.set_meta('has_comments', '0')
      admin_sign_in
      visit @post.the_url(as_path: true)

      expect(page).to have_text(@post.the_title)
      expect(page).to have_no_text('New Comment')
    end
  end

  describe 'post visibility' do
    before do
      current_site(@site)
      plugin_install('visibility_post')
    end

    it 'displays a public post' do
      custom_post = create(:post, site: @site).decorate
      visit custom_post.the_url(as_path: true)

      expect(page).to have_text(custom_post.the_title)
      expect(page).to have_no_text('does not exist')
    end

    it 'public future post with login' do
      custom_post = create(:post, site: @site, published_at: 1.day.from_now).decorate
      admin_sign_in(custom_post.owner.username, '12345678')
      visit custom_post.the_url(as_path: true)
      expect(page).to have_text('does not exist')
    end

    it 'public future post without login' do
      custom_post = create(:post, site: @site, published_at: 1.day.from_now).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_text('does not exist')
    end

    it 'private post without login' do
      custom_post = create(:private_post, site: @site).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_text('does not exist')
    end

    it 'private post with login' do
      user = create(:user, password: '12345678', password_confirmation: '12345678', site: @site)
      custom_post = create(:private_post, site: @site, owner: user).decorate
      admin_sign_in(user.username, '12345678')
      visit custom_post.the_url(as_path: true)

      expect(page).to have_text(custom_post.the_title)
      expect(page).to have_no_text('does not exist')
    end

    it 'password post without password' do
      custom_post = create(:password_post, site: @site).decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_text('Enter the password:')
    end

    it 'password post with password' do
      custom_post = create(:password_post, site: @site, content: '<p>unlocked secret body</p>').decorate
      visit custom_post.the_url(as_path: true)
      expect(page).to have_css('form.protected_form')
      expect(page).to have_no_text('unlocked secret body')

      within('form.protected_form') do
        fill_in 'post_password', with: custom_post.visibility_value
        click_button
      end

      expect(page).to have_text('unlocked secret body')
    end
  end
end
