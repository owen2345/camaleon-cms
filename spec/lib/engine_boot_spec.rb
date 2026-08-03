# frozen_string_literal: true

require 'rails_helper'
require 'open3'

RSpec.describe CamaleonCms::Engine do
  # Hosts that serve public/ from nginx/Apache run with public_file_server disabled,
  # so ActionDispatch::Static is absent from their middleware stack. CI runs with the
  # file server enabled, which is why this needs its own boot in a subprocess.
  it 'boots when public_file_server is disabled' do
    output, status = Open3.capture2e(
      { 'CAMA_TEST_DISABLE_FILE_SERVER' => '1' },
      'bin/rails', 'runner', 'print "BOOTED-OK"',
      chdir: Rails.root.to_s
    )

    expect(output).to include('BOOTED-OK'), "boot failed:\n#{output}"
    expect(status).to be_success
  end
end
