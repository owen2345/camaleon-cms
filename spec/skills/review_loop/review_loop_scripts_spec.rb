# frozen_string_literal: true

# The runner of the review-loop script specs (spec/support/review_loop_scripts.rb).
RSpec.describe 'ReviewLoopScripts' do
  include ReviewLoopScripts

  it 'runs a script from a folder whose path holds a space, also with no argument' do
    write_executable('exit3.sh', "#!/bin/sh\nexit 3\n")
    expect(run_script(File.join(dir, 'exit3.sh')).status).to eq(3)
  end

  it 'runs a new shim once, with --version and no record variable set' do
    body = "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$0.runs\"\nprintf '%s\\0' \"$*\" >> \"$FAKE_CALLS\"\n"
    shim_env('tool', body)
    expect(File.read(File.join(dir, 'bin', 'tool.runs'))).to eq("--version\n")
    expect(fake_calls(dir)).to eq([])
  end

  it 'sets no STAMPS for a shim, so the fakes beside it write no time' do
    expect(shim_env('tool', "#!/bin/sh\n")).not_to have_key('STAMPS')
  end
end
