# frozen_string_literal: true

# Gives the themes of an example hook handlers that record what they see. The specs of the theme
# install and of the site create use it.
RSpec.shared_context 'with theme hook probes' do
  # What the handlers recorded, in the order of their runs.
  let(:hook_log) { [] }

  # Replaces the hooks of each theme in hooks_by_theme (theme slug => hook name => handler names).
  # helper_module defines the handlers.
  def probe_theme_hooks(helper_module, hooks_by_theme)
    stub_const('ThemeHookProbeHelper', helper_module)
    allow(PluginRoutes).to receive(:theme_info).and_wrap_original do |original, key|
      info = original.call(key)
      hooks = hooks_by_theme[key]
      next info if info.nil? || hooks.nil?

      info.merge('helpers' => Array(info['helpers']) + ['ThemeHookProbeHelper'], 'hooks' => hooks)
    end
  end
end
