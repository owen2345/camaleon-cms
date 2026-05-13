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

  describe '.will_restart?' do
    it 'returns false in test environment' do
      allow(Rails.env).to receive(:test?).and_return(true)
      expect(described_class.will_restart?).to be false
    end

    it 'returns false when not in ruby engine' do
      stub_const('RUBY_ENGINE', 'jruby')
      expect(described_class.will_restart?).to be false
    end
  end

  describe 'private server restart methods' do
    describe '#clustered_mode?' do
      it 'returns false by default in test environment' do
        # In test env, clustered_mode? may return false
        expect(described_class.send(:clustered_mode?)).to be false
      end
    end

    describe '#find_master_pid' do
      it 'returns ppid if no pid files exist' do
        allow(Rails.root).to receive(:join).and_return('/fake/path')
        allow(File).to receive(:exist?).and_return(false)
        allow(Process).to receive(:ppid).and_return(123)
        expect(described_class.send(:find_master_pid)).to eq(123)
      end
    end

    describe '#trigger_server_restart_if_clustered' do
      before do
        described_class.remove_instance_variable(:@clustered_mode) if described_class.instance_variable_defined?(:@clustered_mode)
      end

      after do
        described_class.remove_instance_variable(:@clustered_mode) if described_class.instance_variable_defined?(:@clustered_mode)
      end

      it 'sends SIGUSR1 to master pid for Puma in clustered mode (phased restart)' do
        puma_mod = Module.new do
          def self.stats; end
        end
        stub_const('Puma', puma_mod)
        allow(Puma).to receive(:stats).and_return('{"workers":2}')
        allow(Puma).to receive(:respond_to?).with(:cli_config).and_return(false)
        allow(described_class).to receive(:find_master_pid).and_return(12_345)

        expect(Process).to receive(:kill).with('SIGUSR1', 12_345)

        described_class.send(:trigger_server_restart_if_clustered)
      end

      it 'sends SIGUSR2 to master pid for Puma with preload_app (hot restart)' do
        puma_mod = Module.new do
          def self.stats; end

          def self.cli_config; end
        end
        stub_const('Puma', puma_mod)
        cli_config_klass = Struct.new(:options)
        cli_config = instance_double(cli_config_klass, options: { preload_app: true })
        allow(Puma).to receive_messages(stats: '{"workers":2}', cli_config: cli_config)
        allow(described_class).to receive(:find_master_pid).and_return(12_345)

        expect(Process).to receive(:kill).with('SIGUSR2', 12_345)

        described_class.send(:trigger_server_restart_if_clustered)
      end

      it 'does not send signal when not in clustered mode' do
        allow(Process).to receive(:ppid).and_return(1)

        expect(Process).not_to receive(:kill)

        described_class.send(:trigger_server_restart_if_clustered)
      end

      it 'logs error when Process.kill fails' do
        puma_mod = Module.new do
          def self.stats; end
        end
        stub_const('Puma', puma_mod)
        allow(Puma).to receive(:stats).and_return('{"workers":2}')
        allow(Puma).to receive(:respond_to?).with(:cli_config).and_return(false)
        allow(described_class).to receive(:find_master_pid).and_return(99_999)
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH, 'No such process')

        expect(Rails.logger).to receive(:error).with(/Could not trigger server restart/)

        described_class.send(:trigger_server_restart_if_clustered)
      end
    end
  end

  describe '.reload (restart scheduling)' do
    after do
      described_class.instance_variable_set(:@restart_pending, false)
    end

    context 'when will_restart? is true' do
      before do
        allow(described_class).to receive(:will_restart?).and_return(true)
      end

      it 'schedules restart via after_all_transactions_commit' do
        # after_all_transactions_commit fires immediately when no transaction is open
        expect(described_class).to receive(:trigger_server_restart_if_clustered).once

        described_class.reload
      end

      it 'does not call reload_local on first call' do
        allow(described_class).to receive(:trigger_server_restart_if_clustered)

        expect(described_class).not_to receive(:reload_local)

        described_class.reload
      end

      it 'falls back to reload_local on subsequent calls while restart is pending' do
        # Simulate a pending restart by setting the flag
        described_class.instance_variable_set(:@restart_pending, true)

        expect(described_class).to receive(:reload_local).once

        described_class.reload
      end

      it 'calls trigger_server_restart_if_clustered only once for multiple reloads in a transaction' do
        expect(described_class).to receive(:trigger_server_restart_if_clustered).once
        expect(described_class).to receive(:reload_local).twice

        ActiveRecord::Base.transaction do
          3.times { described_class.reload }
        end
      end

      it 'clears restart_pending after transactions commit' do
        allow(described_class).to receive(:trigger_server_restart_if_clustered)

        ActiveRecord::Base.transaction do
          described_class.reload
          expect(described_class.instance_variable_get(:@restart_pending)).to be true
        end

        # After commit, the flag should be cleared
        expect(described_class.instance_variable_get(:@restart_pending)).to be false
      end
    end

    it 'skips nested calls via reloading guard' do
      expect(described_class).to receive(:reload_local).once do
        # Simulate a nested reload call (e.g. from a model callback triggered during reload)
        described_class.reload
      end

      described_class.reload
    end
  end
end
