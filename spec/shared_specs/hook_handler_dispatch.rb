# frozen_string_literal: true

# What a registered hook handler can expect from a dispatcher (OpenSpec: hook-handler-dispatch):
# it runs once per dispatch and a failure inside it reaches the caller; its plugin's helper is
# included first when it is not yet defined; a handler no helper defines is skipped with a warning.
# The dispatchers used to rescue any failure, reload the helpers and run the handler again.
RSpec.shared_examples 'a hook handler dispatcher' do |dispatcher|
  let(:host_class) do
    Class.new do
      include dispatcher
      attr_reader :runs, :others

      def initialize
        @runs = 0
        @others = 0
      end

      def failing_handler(_args)
        @runs += 1
        raise 'handler failed'
      end

      def other_handler(_args)
        @others += 1
      end
    end
  end
  let(:host) { host_class.new }
  let(:plugin) { { 'key' => 'probe', 'helpers' => ['ProbeHookHelper'], 'hooks' => { 'probe_hook' => handlers } } }

  before { stub_const('ProbeHookHelper', helper_module) }

  context 'with a handler that fails after a side effect' do
    let(:handlers) { ['failing_handler'] }
    let(:helper_module) { Module.new }

    it 'runs it once and lets the failure reach the caller' do
      expect { host.send(:_do_hook, plugin, 'probe_hook', {}) }.to raise_error('handler failed')
      expect(host.runs).to eq(1)
    end
  end

  context 'with a handler defined by a helper not yet included' do
    let(:handlers) { ['late_handler'] }
    let(:helper_module) do
      Module.new do
        def late_handler(args)
          args[:ran] = args.fetch(:ran, 0) + 1
        end
      end
    end

    it 'includes the helper and runs the handler once' do
      args = {}

      host.send(:_do_hook, plugin, 'probe_hook', args)

      expect(args[:ran]).to eq(1)
    end
  end

  context 'with a handler no helper defines' do
    let(:handlers) { %w[missing_handler other_handler] }
    let(:helper_module) { Module.new }

    it 'skips it with a warning and runs the next handler' do
      allow(Rails.logger).to receive(:warn)
      expect(Rails.logger).to receive(:warn).with(/probe_hook.*probe.*missing_handler/)

      expect { host.send(:_do_hook, plugin, 'probe_hook', {}) }.not_to raise_error
      expect(host.others).to eq(1)
    end
  end
end
