# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Post, type: :model do
  describe 'content sanitization' do
    let(:site) { create(:site) }
    let(:post_type) { create(:post_type, site: site) }
    let(:admin) { create(:user, role: 'admin', site: site) }
    let(:contributor) { create(:user, role: 'contributor', site: site) }

    def assign_current_user(user)
      CurrentRequest.user = user
      CurrentRequest.site = site
    end

    after do
      CurrentRequest.user = nil
      CurrentRequest.site = nil
    end

    context 'when user lacks allow_unfiltered_html permission' do
      it 'strips script tags from post content' do
        assign_current_user(contributor)
        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<p>Hello</p><script>alert(1)</script><p>World</p>')
        expect(post.content).not_to include('<script>')
        expect(post.content).to include('<p>Hello</p>')
        expect(post.content).to include('<p>World</p>')
      end

      it 'strips SVG onbegin event handlers' do
        assign_current_user(contributor)
        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<svg xmlns="http://www.w3.org/2000/svg"><animate onbegin="alert(1)"/></svg>')
        expect(post.content).not_to include('onbegin')
        expect(post.content).not_to include('alert(1)')
      end

      it 'strips javascript: URLs from links' do
        assign_current_user(contributor)
        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<a href="javascript:alert(1)">click</a>')
        expect(post.content).not_to include('javascript:')
      end

      it 'strips onerror event handlers from images' do
        assign_current_user(contributor)
        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<img src="x.png" onerror="alert(1)">')
        expect(post.content).not_to include('onerror')
        expect(post.content).to include('src')
      end

      it 'preserves safe HTML tags' do
        assign_current_user(contributor)
        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<p>Text</p><strong>Bold</strong><a href="https://example.com">Link</a><ul><li>Item</li></ul>')
        expect(post.content).to include('<p>')
        expect(post.content).to include('<strong>')
        expect(post.content).to include('<a href="https://example.com"')
        expect(post.content).to include('<ul>')
        expect(post.content).to include('<li>')
      end

      it 'sanitizes content on update as well as create' do
        assign_current_user(contributor)
        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<p>Safe content</p>')
        post.update!(content: '<p>Safe</p><script>alert(1)</script>')
        expect(post.content).not_to include('<script>')
        expect(post.content).to include('<p>Safe</p>')
      end
    end

    context 'when user has allow_unfiltered_html permission' do
      it 'preserves script tags for admin' do
        assign_current_user(admin)
        post = create(:post, post_type: post_type, owner: admin,
                             content: '<p>Content</p><script>validAppCode()</script>')
        expect(post.content).to include('<script>')
        expect(post.content).to include('validAppCode()')
      end

      it 'preserves iframes for admin' do
        assign_current_user(admin)
        post = create(:post, post_type: post_type, owner: admin,
                             content: '<iframe src="https://example.com/embed"></iframe>')
        expect(post.content).to include('<iframe')
      end
    end

    context 'translation-tag handling for untrusted content' do
      it 'does not turn literal !-- / --! typed by a user into HTML comment delimiters' do
        assign_current_user(contributor)

        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<p>Big Sale !-- 50% off --!</p>')

        expect(post.content).not_to include('<!--')
        expect(post.content).not_to include('-->')
        expect(post.content).to include('!--')
        expect(post.content).to include('--!')
      end

      it 'preserves multilingual locale markers through sanitization' do
        assign_current_user(contributor)

        post = create(:post, post_type: post_type, owner: contributor,
                             content: '<!--:en-->Hello<!--:--><!--:es-->Hola<!--:-->')

        expect(post.content).to include('<!--:en-->')
        expect(post.content).to include('<!--:es-->')
        expect(post.content).to include('Hello')
        expect(post.content).to include('Hola')
      end
    end

    context 'when user context is absent' do
      it 'applies sanitization with no user set (fail-safe)' do
        CurrentRequest.user = nil
        CurrentRequest.site = site
        post = create(:post, post_type: post_type,
                             content: '<p>Text</p><script>alert(1)</script>')
        expect(post.content).not_to include('<script>')
        expect(post.content).to include('<p>Text</p>')
      end
    end

    context 'when a non-admin user is present but site context is absent' do
      it 'sanitizes instead of raising (fail-safe, e.g. background jobs)' do
        CurrentRequest.user = contributor
        CurrentRequest.site = nil

        post = nil
        expect do
          post = create(:post, post_type: post_type, owner: contributor,
                               content: '<p>Text</p><script>alert(1)</script>')
        end.not_to raise_error
        expect(post.content).not_to include('<script>')
        expect(post.content).to include('<p>Text</p>')
      end
    end
  end
end
