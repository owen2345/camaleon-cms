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
end
