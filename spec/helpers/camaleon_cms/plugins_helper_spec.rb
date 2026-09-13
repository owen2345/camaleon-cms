# frozen_string_literal: true

RSpec.describe CamaleonCms::PluginsHelper do
  describe '#plugin_load_helpers' do
    # A view includes a plugin's helpers into its own singleton class. The loader checked only the
    # class, so every call included the module again and ran its included hook again.
    it 'includes a declared helper into the object once, however often it runs' do
      inclusions = []
      helper = stub_const('ProbeLoadedHelper', Module.new)
      helper.define_singleton_method(:included) { |base| inclusions << base }
      host = Class.new { include CamaleonCms::PluginsHelper }.new

      2.times { host.plugin_load_helpers('helpers' => ['ProbeLoadedHelper']) }

      expect(host).to be_a(ProbeLoadedHelper)
      expect(inclusions.size).to eq(1)
    end
  end
end
