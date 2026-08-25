# frozen_string_literal: true

# Security (audit Low): front_cache keyed its page cache on `uri.parameterize`, which lowercases and
# collapses every run of non-alphanumerics to a single '-'. Distinct URLs therefore share a cache
# entry, so a visitor to one cacheable URL can be served the cached body of another. The key is now a
# lossless digest. Separately, admin-configured path patterns were compiled with `Regexp.new` on
# every request with no rescue, so a malformed pattern raised (500).
RSpec.describe Plugins::FrontCache::FrontCacheHelper do
  let(:harness_class) { front_cache_host_class(:request) }
  let(:host) { harness_class.new }

  describe '#front_cache_plugin_cache_key' do
    def key_for(fullpath)
      host.request = instance_double(
        ActionDispatch::Request, protocol: 'http://', host_with_port: 'example.com', fullpath: fullpath
      )
      host.send(:front_cache_plugin_cache_key)
    end

    it 'maps URLs that differ only in separators to distinct cache keys' do
      expect(key_for('/a/b')).not_to eq(key_for('/a-b'))
    end
  end

  describe '#front_cache_plugin_match_path_patterns?' do
    it 'ignores an invalid path pattern instead of raising' do
      host.instance_variable_set(:@caches, { paths: ['[invalid'] })

      expect { host.send(:front_cache_plugin_match_path_patterns?, '/x', '/y') }.not_to raise_error
    end

    it 'ignores a non-String path pattern instead of raising' do
      host.instance_variable_set(:@caches, { paths: [['nested-array']] })

      expect { host.send(:front_cache_plugin_match_path_patterns?, '/x', '/y') }.not_to raise_error
    end
  end
end
