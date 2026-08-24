# frozen_string_literal: true

# Security — front_cache invalidation must be scoped to its own entries (frontend-cache-invalidation-scope).
#
# front_cache_post_requests is hooked on front_before_load AND admin_before_load, and on every
# POST/PATCH it called front_cache_clean, which (unless the opt-in invalidate_only mode was set) ran
# Rails.cache.clear — emptying the SHARED cache store. Every Rails.cache-based counter was destroyed
# on each such POST. The login POST itself runs no front_cache hook (SessionsController inherits
# CamaleonController, which fires only session_before_load) — but any unauthenticated frontend POST
# (a comment, a contact form) or any admin POST wiped the per-IP login brute-force counter
# (CaptchaHelper, login-brute-force-protection), so an attacker could reset their own counter
# between login attempts with one cheap frontend POST, silently defeating the captcha gate and
# lockout.
#
# These specs drive the helper on a harness class against a real MemoryStore and assert on the
# underlying store. (MemoryStore#with_local_cache exists only since Rails 8.1.2, so the per-request
# LocalCache is not simulated here — it is write-through, so it does not change what the store
# holds between simulated requests.)
RSpec.describe Plugins::FrontCache::FrontCacheHelper do
  let(:harness_class) do
    Class.new do
      include Plugins::FrontCache::FrontCacheHelper
      attr_accessor :current_site, :request
    end
  end
  let(:store) { ActiveSupport::Cache::MemoryStore.new }
  let(:meta) { { paths: [], posts: [], post_types: [], skip_posts: [], home: true } }
  let(:versions) { { 'front_cache_counter' => nil } }
  let(:site) do
    site = double('site', id: 1) # rubocop:disable RSpec/VerifiedDoubles -- decorated site quacks many classes
    allow(site).to receive(:get_meta).with('front_cache_elements').and_return(meta)
    allow(site).to receive(:set_meta).with('front_cache_elements', anything) { |_key, value| meta.replace(value) }
    allow(site).to receive(:get_meta).with('front_cache_counter') { versions['front_cache_counter'] }
    allow(site).to receive(:set_meta).with('front_cache_counter', anything) do |_key, value|
      versions['front_cache_counter'] = value
    end
    site
  end
  let(:host) { harness_class.new.tap { |h| h.current_site = site } }

  def stored_version
    versions['front_cache_counter']
  end

  before { allow(Rails).to receive(:cache).and_return(store) }

  describe '#front_cache_clean' do
    it 'preserves cache entries it does not own, such as the login brute-force counter' do
      store.write('cama_captcha_attack:1:203.0.113.9:login', 3, raw: true)

      host.front_cache_clean

      expect(store.read('cama_captcha_attack:1:203.0.113.9:login', raw: true).to_i).to eq(3)
    end

    it 'still invalidates the cached pages of the site' do
      host.send(:front_cache_plugin_cache_create, 'key', 'cached body')
      expect(host.send(:front_cache_exist?, 'key')).to be true

      host.front_cache_clean

      expect(host.send(:front_cache_exist?, 'key')).to be false
    end

    it 'overwrites the retired entry in place when the page is re-cached (one entry per URL)' do
      host.send(:front_cache_plugin_cache_create, 'key', 'old body')
      expect(store.read('cama_front_cache/1/key', version: 0)).to eq('old body')

      host.front_cache_clean
      host.send(:front_cache_plugin_cache_create, 'key', 'new body')

      # the single physical entry now holds only the new generation
      expect(store.read('cama_front_cache/1/key', version: 0)).to be_nil
      expect(store.read('cama_front_cache/1/key', version: 1)).to eq('new body')
    end

    it 'does not touch the page cache of another site, including one whose id shares a digit prefix' do
      store.write('cama_front_cache/11/other-site-key', 'other site body')

      host.front_cache_clean

      expect(store.read('cama_front_cache/11/other-site-key')).to eq('other site body')
    end

    it 'performs no store enumeration on the request path' do
      allow(store).to receive(:delete_matched)

      host.front_cache_clean

      expect(store).not_to have_received(:delete_matched)
      expect(stored_version).to eq(1)
    end

    it 'starts from version zero on a site that has never invalidated' do
      expect(stored_version).to be_nil

      host.front_cache_clean

      expect(stored_version).to eq(1)
    end

    it 'never writes the settings meta, so a settings save cannot revert the version' do
      host.front_cache_clean

      expect(site).not_to have_received(:set_meta).with('front_cache_elements', anything)
      expect(stored_version).to eq(1)
    end
  end

  describe '#front_cache_purge_stored_pages (the explicit admin "Clean cache" action)' do
    it "removes the site's stored pages but not another site's, nor entries it does not own" do
      host.send(:front_cache_plugin_cache_create, 'key', 'cached body')
      store.write('cama_front_cache/11/other-site-key', 'other site body')
      store.write('cama_captcha_attack:1:203.0.113.9:login', 3, raw: true)

      host.send(:front_cache_purge_stored_pages)

      expect(store.read('cama_front_cache/1/key', version: 0)).to be_nil
      expect(store.read('cama_front_cache/11/other-site-key')).to eq('other site body')
      expect(store.read('cama_captcha_attack:1:203.0.113.9:login', raw: true).to_i).to eq(3)
    end

    it 'purges on a store configured with a namespace (key_matcher composes a leading ^)' do
      namespaced = ActiveSupport::Cache::MemoryStore.new(namespace: 'app1')
      allow(Rails).to receive(:cache).and_return(namespaced)
      host.send(:front_cache_plugin_cache_create, 'key', 'cached body')
      expect(namespaced.read('cama_front_cache/1/key', version: 0)).to eq('cached body')

      host.send(:front_cache_purge_stored_pages)

      expect(namespaced.read('cama_front_cache/1/key', version: 0)).to be_nil
    end

    [NotImplementedError, ArgumentError, RuntimeError].each do |error_class|
      it "logs and continues when the store raises #{error_class}" do
        allow(store).to receive(:delete_matched).and_raise(error_class)
        allow(Rails.logger).to receive(:warn)

        expect { host.send(:front_cache_purge_stored_pages) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(/front_cache purge skipped/)
      end
    end
  end

  describe '#front_cache_post_requests' do
    def run_request_lifecycle(counter_key)
      # the per-IP counter pattern of CamaleonCms::CaptchaHelper#cama_captcha_increment_attack
      counted = Rails.cache.increment(counter_key, 1, expires_in: 15.minutes, raw: true)
      Rails.cache.write(counter_key, 1, expires_in: 15.minutes, raw: true) if counted.nil?
      host.front_cache_post_requests
    end

    it 'lets a per-IP counter accumulate across POST request lifecycles while pages are invalidated' do
      host.request = instance_double(ActionDispatch::Request, post?: true, patch?: false)
      counter_key = 'cama_captcha_attack:1:203.0.113.9:login'

      2.times { run_request_lifecycle(counter_key) }

      expect(store.read(counter_key, raw: true).to_i).to eq(2)
      expect(stored_version).to eq(2)
    end

    it 'does not invalidate on GET requests' do
      host.request = instance_double(ActionDispatch::Request, post?: false, patch?: false)

      host.front_cache_post_requests

      expect(stored_version).to be_nil
    end
  end
end
