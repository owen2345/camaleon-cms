# frozen_string_literal: true

require 'rails_helper'
require 'open3'

RSpec.describe CamaleonCms::Engine do
  # Hosts that serve public/ from nginx/Apache run with public_file_server disabled,
  # so ActionDispatch::Static is absent from their middleware stack. CI runs with the
  # file server enabled, which is why this needs its own boot in a subprocess.
  # The subprocess reports the two facts the assertion needs, because a boot that succeeded with
  # the file server still enabled proves nothing: if the env flag stopped taking effect — renamed,
  # or the environment file stopped reading it — the boot would pass and the example would stay
  # green while covering the opposite configuration.
  it 'boots when public_file_server is disabled' do
    # Reporting the middleware stack instead would prove nothing: the engine appends its own
    # ActionDispatch::Static for the engine's public dir either way, so it is present regardless.
    # config.public_file_server.enabled is what decides whether the *host* gets one, which is the
    # condition the boot used to abort on.
    # Single-quoted heredoc: the interpolation must survive verbatim into the subprocess. A
    # double-quoted form would evaluate it here and merely echo this process's own setting.
    probe = <<~'RUBY'.strip
      print "BOOTED-OK file_server=#{Rails.application.config.public_file_server.enabled}"
    RUBY
    output, status = Open3.capture2e(
      { 'CAMA_TEST_DISABLE_FILE_SERVER' => '1' },
      'bin/rails', 'runner', probe,
      chdir: Rails.root.to_s
    )

    expect(output).to include('BOOTED-OK'), "boot failed:\n#{output}"
    expect(status).to be_success
    expect(output).to include('file_server=false'), "the env flag did not disable the file server:\n#{output}"
  end

  # The eager boot draw is wired as a named engine initializer, so a rename or a dropped hook is
  # caught here rather than silently disabling the draw (every draw_routes_eagerly unit spec would
  # still pass). It must be anchored after Rails' :set_routes_reloader_hook so the route set
  # (internal + host routes) is fully assembled first.
  describe 'eager route draw wiring' do
    let(:ordered_names) { Rails.application.initializers.tsort.map(&:name) }

    it 'registers the cama_draw_routes_eagerly initializer' do
      expect(ordered_names).to include(:cama_draw_routes_eagerly)
    end

    it 'runs the draw after the routes reloader hook' do
      expect(ordered_names.index(:cama_draw_routes_eagerly))
        .to be > ordered_names.index(:set_routes_reloader_hook)
    end

    it 'keeps the middleware-mutating initializer before the stack is built' do
      # Guards the "declared last" placement: the draw's cross-cutting `after:` must not reorder the
      # engine's earlier :append_migrations (which inserts middleware) past :build_middleware_stack,
      # which freezes the stack.
      expect(ordered_names.index(:append_migrations))
        .to be < ordered_names.index(:build_middleware_stack)
    end
  end
end
