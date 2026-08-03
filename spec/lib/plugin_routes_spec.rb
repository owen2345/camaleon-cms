# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PluginRoutes do
  describe '.add_after_reload_routes' do
    after do
      # Clean up the instance variable to avoid polluting other tests
      described_class.instance_variable_set(:@after_reload_callbacks, [])
    end

    it 'accepts a Proc' do
      callable = proc { 'hello' }
      expect { described_class.add_after_reload_routes(callable) }.not_to raise_error
    end

    it 'accepts a Lambda' do
      callable = -> { 'hello' }
      expect { described_class.add_after_reload_routes(callable) }.not_to raise_error
    end

    it 'raises ArgumentError for a String' do
      expect { described_class.add_after_reload_routes('puts "hello"') }
        .to raise_error(ArgumentError, /callable/)
    end
  end

  describe '.reload' do
    it 'calls each registered callable' do
      callback = instance_double(Proc)
      described_class.instance_variable_set(:@after_reload_callbacks, [callback])

      allow(Rails.application).to receive(:reload_routes!)

      expect(callback).to receive(:call)

      described_class.reload

      # Clean up
      described_class.instance_variable_set(:@after_reload_callbacks, [])
    end

    it 'clears the cache before reloading routes' do
      # Set a cache value
      described_class.cache_variable('test_key', 'test_value')
      expect(described_class.cache_variable('test_key')).to eq('test_value')

      # Mock reload_routes! to not actually reload
      allow(Rails.application).to receive(:reload_routes!)

      described_class.reload

      # Cache should be cleared
      expect(described_class.cache_variable('test_key')).to be_nil
    end
  end

  describe '.cache_variable' do
    before do
      # Clear cache before each test
      described_class.instance_variable_set(:@cache, {})
    end

    it 'stores and retrieves values' do
      described_class.cache_variable('my_key', 'my_value')
      expect(described_class.cache_variable('my_key')).to eq('my_value')
    end

    it 'returns nil for nonexistent keys' do
      expect(described_class.cache_variable('nonexistent')).to be_nil
    end

    it 'overwrites existing values' do
      described_class.cache_variable('key', 'value1')
      described_class.cache_variable('key', 'value2')
      expect(described_class.cache_variable('key')).to eq('value2')
    end
  end

  describe '.plugin_info' do
    it 'returns plugin info by key' do
      # Stub all_plugins to return a known plugin
      plugin = { 'key' => 'test_plugin', 'name' => 'Test Plugin' }
      allow(described_class).to receive(:all_plugins).and_return([plugin])

      expect(described_class.plugin_info('test_plugin')).to eq(plugin)
    end

    it 'returns nil for nonexistent plugin' do
      allow(described_class).to receive(:all_plugins).and_return([])

      expect(described_class.plugin_info('nonexistent')).to be_nil
    end

    it 'finds plugin by path basename' do
      plugin = { 'key' => 'my_plugin', 'path' => '/some/path/my_plugin' }
      allow(described_class).to receive(:all_plugins).and_return([plugin])

      expect(described_class.plugin_info('my_plugin')).to eq(plugin)
    end
  end

  describe '.theme_info' do
    it 'returns theme info by key' do
      theme = { 'key' => 'test_theme', 'name' => 'Test Theme' }
      allow(described_class).to receive(:all_themes).and_return([theme])

      expect(described_class.theme_info('test_theme')).to eq(theme)
    end

    it 'returns nil for nonexistent theme' do
      allow(described_class).to receive(:all_themes).and_return([])

      expect(described_class.theme_info('nonexistent')).to be_nil
    end
  end

  describe 'class instance variables' do
    it 'uses class instance variables instead of class variables' do
      # Verify that we're using class instance variables (no @@)
      expect(described_class.instance_variable_defined?(:@cache)).to be true
      expect(described_class.instance_variable_defined?(:@reload_monitor)).to be true
      expect(described_class.instance_variable_defined?(:@after_reload_callbacks)).to be true
    end

    it 'does not have class variables' do
      # Ensure we're not using class variables anymore
      expect { described_class.class_variable_get(:@@cache) }.to raise_error(NameError)
    end
  end

  describe '.all_helpers' do
    after { described_class.send(:cache).delete('plugins_helper') }

    it 'omits apps that declare no helpers' do
      described_class.send(:cache).delete('plugins_helper')
      apps = [
        { 'key' => 'no_helpers_key' },
        { 'key' => 'empty_helpers', 'helpers' => [] },
        { 'key' => 'with_helpers', 'helpers' => ['CamaleonCms::CamaleonHelper'] }
      ]
      allow(described_class).to receive(:all_apps).and_return(apps)

      expect(described_class.all_helpers).to eq(['CamaleonCms::CamaleonHelper'])
    end
  end

  describe '.site_plugin_helpers' do
    after { described_class.send(:cache).delete('site_plugin_helpers') }

    it 'omits enabled apps that declare no helpers' do
      described_class.send(:cache).delete('site_plugin_helpers')
      apps = [
        { 'key' => 'no_helpers_key' },
        { 'key' => 'with_helpers', 'helpers' => ['CamaleonCms::CamaleonHelper'] }
      ]
      site = instance_double(CamaleonCms::Site)
      allow(described_class).to receive(:enabled_apps).with(site).and_return(apps)

      expect(described_class.site_plugin_helpers(site)).to eq(['CamaleonCms::CamaleonHelper'])
    end
  end
end
