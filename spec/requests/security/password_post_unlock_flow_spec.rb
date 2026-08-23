# frozen_string_literal: true

include CamaleonCms::PluginsHelper

# Security (audit 2026-08-11 M2): the password-post prompt was a method-less form (GET) with a
# text-type input, so the password landed in URLs, logs and referrers, and the comparison used `==`.
# Unlocking now goes through a plugin POST endpoint that compares in constant time and marks the post
# unlocked in the session; the query-string parameter no longer unlocks anything.
RSpec.describe 'Password post unlock flow', type: :request do
  init_site

  let(:secret) { 'unlockedbodymarker' }

  before do
    current_site(@site)
    plugin_install('visibility_post')
    @locked = create(:password_post, site: @site, post_type: @site.post_types.find_by(slug: 'post'),
                                     content: "<p>#{secret} rest of the body</p>").decorate
  end

  it 'no longer unlocks through the GET post_password parameter' do
    get @locked.the_url(as_path: true), params: { post_password: @locked.visibility_value }

    expect(response.body).not_to include(secret)
    expect(response.body).to include('protected_form')
  end

  it 'renders the prompt as a POST form with a password-type input' do
    get @locked.the_url(as_path: true)

    expect(response.body).to include("method='post'")
    expect(response.body).to include("action='/plugins/visibility_post/unlock/#{@locked.id}'")
    expect(response.body).to include("type='password'")
    expect(response.body).to include("name='authenticity_token'")
  end

  it 'keeps the post locked after a wrong password and unlocks the session after the right one' do
    post "/plugins/visibility_post/unlock/#{@locked.id}", params: { post_password: 'not-it' }
    expect(response).to redirect_to(@locked.the_url(as_path: true))
    follow_redirect!
    expect(response.body).not_to include(secret)
    expect(response.body).to include('Wrong password')

    post "/plugins/visibility_post/unlock/#{@locked.id}", params: { post_password: @locked.visibility_value }
    follow_redirect!
    expect(response.body).to include(secret)

    # the unlock is session-side: a later plain GET stays unlocked, with no password anywhere
    get @locked.the_url(as_path: true)
    expect(response.body).to include(secret)
  end

  it 'refuses to unlock a post that is not password-protected' do
    open_post = create(:post, site: @site, post_type: @site.post_types.find_by(slug: 'post'))

    post "/plugins/visibility_post/unlock/#{open_post.id}", params: { post_password: 'anything' }

    expect(response).to have_http_status(:not_found)
  end
end
