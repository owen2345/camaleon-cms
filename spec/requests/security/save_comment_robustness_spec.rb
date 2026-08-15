# frozen_string_literal: true

require 'rails_helper'

# Security (audit Low): save_comment is a public, unauthenticated endpoint. A POST naming a
# non-existent post id reached `current_site.posts.find_by(id: ...).decorate` on nil (NoMethodError
# → 500), and the anonymous branch indexed `params[:post_comment]` without a nil-guard. Crafted
# requests should get a graceful error, not a 500 an attacker can trigger at will.
RSpec.describe 'Security: save_comment tolerates crafted input (Low)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  it 'does not 500 when the post id names no post' do
    post '/save_comment/999999', params: { format: 'json' }

    expect(response).to have_http_status(:ok)
  end

  it 'does not 500 when post_comment is missing on an anonymous submission' do
    current_site.set_option('permit_anonimos_comment', true)
    post_record = current_site.post_types.find_by(slug: 'post')
                              .posts.create!(title: 'Commentable', slug: 'commentable', status: 'published')
    post_record.set_option('has_comments', true)
    post_record.set_meta('has_comments', '1')

    post "/save_comment/#{post_record.id}", params: { format: 'json' }

    expect(response).to have_http_status(:ok)
  end

  it 'does not 500 when post_comment[parent_id] names no comment on the post' do
    current_site.set_option('permit_anonimos_comment', true)
    post_record = commentable_post('commentable-parent')

    post "/save_comment/#{post_record.id}",
         params: { format: 'json', post_comment: { content: 'hi', parent_id: 999_999 } }

    expect(response).to have_http_status(:ok)
  end

  it 'does not 500 when post_comment arrives as a scalar instead of a hash' do
    current_site.set_option('permit_anonimos_comment', true)
    post_record = commentable_post('commentable-scalar')

    post "/save_comment/#{post_record.id}", params: { format: 'json', post_comment: 'foo' }

    expect(response).to have_http_status(:ok)
  end

  it 'does not honor an off-host Referer when redirecting (no open redirect or 500)' do
    post '/save_comment/999999',
         params: { post_comment: { content: 'hi' } },
         headers: { 'HTTP_REFERER' => 'https://evil.example.com/phish' }

    expect(response).to have_http_status(:redirect)
    expect(response.location).not_to include('evil.example.com')
  end

  it 'still honors a same-host Referer when redirecting' do
    post '/save_comment/999999',
         params: { post_comment: { content: 'hi' } },
         headers: { 'HTTP_REFERER' => 'http://www.example.com/some/page' }

    expect(response).to redirect_to('http://www.example.com/some/page')
  end

  def commentable_post(slug)
    post_record = current_site.post_types.find_by(slug: 'post')
                              .posts.create!(title: 'Commentable', slug: slug, status: 'published')
    post_record.set_option('has_comments', true)
    post_record.set_meta('has_comments', '1')
    post_record
  end
end
