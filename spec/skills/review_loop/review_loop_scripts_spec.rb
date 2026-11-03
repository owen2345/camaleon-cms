# frozen_string_literal: true

# The runner of the review-loop script specs (spec/support/review_loop_scripts.rb).
RSpec.describe 'ReviewLoopScripts' do
  include ReviewLoopScripts

  it 'runs a script from a folder whose path holds a space, also with no argument' do
    write_executable('exit3.sh', "#!/bin/sh\nexit 3\n")
    expect(run_script(File.join(dir, 'exit3.sh')).status).to eq(3)
  end
end
