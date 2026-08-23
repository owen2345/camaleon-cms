# frozen_string_literal: true

# Audit M2 — a password-protected post must not be page-cached.
#
# front_cache keys its page cache on the URL alone. A password post is unlocked per session
# (visibility_post), so caching an unlocked render would replay the protected body to visitors who
# never entered the password. front_cache short-circuits in the test environment, so this drives the
# caching decision (front_cache_front_before_load -> @_plugin_do_cache) directly with the environment
# guard stubbed off.
RSpec.describe Plugins::FrontCache::FrontCacheHelper do
  # Minimal host object for the plugin helper: the controller collaborators it reads are supplied as
  # real accessors (so partial-double verification is satisfied), and the two cache-path helpers are
  # overridden to avoid the real ones touching Rails.cache / request internals we do not model here.
  let(:harness_class) do
    Class.new do
      include Plugins::FrontCache::FrontCacheHelper
      attr_accessor :current_site, :request, :response, :params, :flash

      def signin?
        false
      end

      def front_cache_plugin_cache_key
        'k'
      end

      def front_cache_exist?(_key)
        false
      end
    end
  end
  let(:caches) { { paths: [], posts: [], post_types: ['5'], skip_posts: [], home: false } }

  def cache_decision_for(visibility)
    decorated = double('post', can_visit?: true, visibility: visibility, id: 9, post_type_id: 5) # rubocop:disable RSpec/VerifiedDoubles
    site = double('site') # rubocop:disable RSpec/VerifiedDoubles
    allow(site).to receive(:get_option).with('refresh_cache').and_return(false)
    allow(site).to receive(:get_meta).with('front_cache_elements').and_return(caches)
    # front_cache resolves the post through the single-record the_post (eager: false), which returns
    # the decorated post directly
    allow(site).to receive(:the_post).with('p').and_return(decorated)
    allow(Rails.env).to receive_messages(development?: false, test?: false)

    host = harness_class.new
    host.current_site = site
    host.request = double('request', get?: true, original_url: 'http://x/p.html', path_info: '/p.html') # rubocop:disable RSpec/VerifiedDoubles
    host.response = double('response', headers: {}) # rubocop:disable RSpec/VerifiedDoubles
    host.params = { action: 'post', controller: 'camaleon_cms/frontend', draft_id: nil, slug: 'p' }
    host.flash = {}
    host.front_cache_front_before_load
    host.instance_variable_get(:@_plugin_do_cache)
  end

  it 'does not cache a password-protected post' do
    expect(cache_decision_for('password')).to be_falsey
  end

  it 'still caches a public post of a cached post type' do
    expect(cache_decision_for('public')).to be true
  end
end
