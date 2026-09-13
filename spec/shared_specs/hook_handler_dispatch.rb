# frozen_string_literal: true

# What a registered hook handler can expect from a dispatcher (OpenSpec: hook-handler-dispatch):
# its plugin's helpers are included before it runs, it runs once per dispatch, and a failure inside
# it reaches the caller, as does a handler nothing defines. The dispatchers used to rescue any
# failure, reload the helpers and run the handler again.
RSpec.shared_examples 'a hook handler dispatcher' do |dispatcher|
  let(:host_class) do
    Class.new do
      include dispatcher

      def failing_handler(args)
        args[:ran] = args.fetch(:ran, 0) + 1
        raise 'handler failed'
      end

      def handler_calling_missing_super(args)
        args[:ran] = args.fetch(:ran, 0) + 1
        super
      end

      def other_handler(args)
        args[:others] = args.fetch(:others, 0) + 1
      end
    end
  end
  let(:host) { host_class.new }
  let(:args) { {} }
  let(:helper_module) { Module.new }
  let(:plugin) { { 'key' => 'probe', 'helpers' => ['ProbeHookHelper'], 'hooks' => { 'probe_hook' => handlers } } }

  before { stub_const('ProbeHookHelper', helper_module) }

  context 'with a handler that fails after a side effect' do
    let(:handlers) { ['failing_handler'] }

    it 'runs it once and lets the failure reach the caller' do
      expect { host.hook_run(plugin, 'probe_hook', args) }.to raise_error('handler failed')
      expect(args[:ran]).to eq(1)
    end
  end

  # A NoMethodError naming the handler is what a rescue narrowed to missing handlers would take for a
  # helper not yet loaded; raised from the handler's own code, it still reaches the caller after one run.
  context 'with a handler whose own code raises NoMethodError naming it' do
    let(:handlers) { ['handler_calling_missing_super'] }

    it 'runs it once and lets that NoMethodError reach the caller' do
      expect { host.hook_run(plugin, 'probe_hook', args) }
        .to raise_error(NoMethodError, /handler_calling_missing_super/)
      expect(args[:ran]).to eq(1)
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
      host.hook_run(plugin, 'probe_hook', args)

      expect(args[:ran]).to eq(1)
    end
  end

  # respond_to? cannot tell whether a plugin's helper still has to be included: the host may already
  # answer the name, as Kernel#format does here and Draper's HelperProxy does once it forwarded it.
  context 'with a handler named like a method the host already answers' do
    let(:handlers) { ['format'] }
    let(:helper_module) do
      Module.new do
        def format(args)
          args[:ran] = args.fetch(:ran, 0) + 1
        end
      end
    end

    it "includes the plugin's helper first and runs its method" do
      host.hook_run(plugin, 'probe_hook', args)

      expect(args[:ran]).to eq(1)
    end
  end

  # Nothing is checked before the call, so a handler nothing defines fails the dispatch as a failing
  # handler does, and a hook that gates content fails closed instead of losing its gate.
  context 'with a handler no helper defines' do
    let(:handlers) { %w[missing_handler other_handler] }

    it 'raises NoMethodError for it and runs no later handler' do
      expect { host.hook_run(plugin, 'probe_hook', args) }.to raise_error(NoMethodError, /missing_handler/)
      expect(args).not_to have_key(:others)
    end
  end

  context 'with a handler its helper answers through method_missing' do
    let(:handlers) { ['answered_handler'] }
    let(:helper_module) do
      Module.new do
        # Deliberately without respond_to_missing?: the dispatcher calls a handler, it does not ask.
        def method_missing(name, *arguments) # rubocop:disable Style/MissingRespondToMissing
          return super unless name == :answered_handler

          arguments.first[:ran] = arguments.first.fetch(:ran, 0) + 1
        end
      end
    end

    it 'runs it once' do
      host.hook_run(plugin, 'probe_hook', args)

      expect(args[:ran]).to eq(1)
    end
  end
end
