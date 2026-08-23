# frozen_string_literal: true

include CamaleonCms::PluginsHelper

# Security (audit 2026-08-11 M1): the visibility_post password gate covered only `the_content`, while
# `the_excerpt` -- rendered by listing pages, search results and every RSS builder -- was computed
# from the post body and emitted ungated. Any visitor could read the beginning of a password-protected
# post without the password. The plugin now registers the `post_the_excerpt` hook and replaces the
# excerpt of a still-locked post with a neutral notice.
RSpec.describe 'Password-protected post excerpt leakage', type: :request do
  init_site

  let(:secret) { 'zecretbodymarker' }

  before do
    current_site(@site)
    plugin_install('visibility_post')
    # The rss builder lists the site's `post` post type, so attach explicitly (the factory would
    # otherwise create its own post type).
    @post_type = @site.post_types.find_by(slug: 'post')
    @locked = create(:password_post, site: @site, post_type: @post_type,
                                     content: "<p>#{secret} rest of the protected body</p>").decorate
  end

  it 'does not leak a locked post body through the RSS feed excerpt' do
    get '/rss'

    expect(response.body).to include(@locked.the_title)
    expect(response.body).not_to include(secret)
    expect(response.body).to include('This content is password protected.')
  end

  # Listing pages and search results show posts through `the_excerpt` (e.g. the default theme's
  # `_post_list_item`), so the decorator API itself must return the neutral notice while locked.
  it 'replaces the_excerpt of a locked post for every listing consumer' do
    expect(@locked.the_excerpt).to eq('This content is password protected.')
  end

  it 'still renders a public post excerpt in the feed' do
    create(:post, site: @site, post_type: @post_type, content: '<p>open body visible to everyone</p>')

    get '/rss'

    expect(response.body).to include('open body visible to everyone')
    expect(response.body).not_to include(secret)
    # exactly one item (the locked post) carries the protected notice
    expect(response.body.scan('This content is password protected.').size).to eq(1)
  end
end
