# frozen_string_literal: true
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

  # The boot draw is wired as a config.after_initialize callback (see the engine), deliberately NOT
  # as a named `initializer :cama_draw_routes_eagerly, after: :set_routes_reloader_hook`. Anchoring a
  # CamaleonCms::Engine initializer to that late Finisher hook adds a cross-cutting edge to Rails'
  # initializer tsort that reorders the append_assets_path initializers: on a host app with several
  # gem-packaged engines it drops their asset load paths (and the host's own app/assets) from
  # config.assets.paths, so plugin assets and core camaleon_cms images raise AssetNotPrecompiledError
  # and 500 the site. The dummy app has too few engines to drop a path, so this guards the wiring
  # shape instead -- reintroducing the named-initializer form flips this red.
  it 'does not wire the boot draw as a tsort-perturbing named initializer' do
    names = Rails.application.initializers.map(&:name)
    expect(names).not_to include(:cama_draw_routes_eagerly)
  end
end
