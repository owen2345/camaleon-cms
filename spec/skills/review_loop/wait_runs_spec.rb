# frozen_string_literal: true

# The wait until no spec run is active (docs/ai/testing.md, Which specs to run): the run markers of a checkout,
# or pgrep for a host app.
RSpec.describe 'scripts/wait-runs.sh' do
  include ReviewLoopScripts

  let(:held) { [] }

  let(:markers) { File.join(dir, 'checkout/tmp/rspec-runs') }

  after { held.each(&:close) }

  def marker(name, locked:)
    FileUtils.mkdir_p(markers)
    path = File.join(markers, name)
    File.write(path, '')
    return unless locked

    file = File.open(path)
    file.flock(File::LOCK_EX)
    held << file
    file
  end

  def wait(*args, answers: [])
    run_script('wait-runs.sh', *args, answers: answers)
  end

  context 'with a checkout' do
    let(:checkout) { File.join(dir, 'checkout') }

    it 'exits with 0 at once when the checkout has no run marker directory' do
      result = wait(checkout)
      expect(result.out).to eq('')
      expect(result.status).to eq(0)
    end

    it 'exits with 0 when no run holds the lock of a run marker' do
      marker('rspec-1-1.pid', locked: false)
      expect(wait(checkout).status).to eq(0)
    end

    it 'waits while a run holds the lock, and exits with 0 when it releases it' do
      file = marker('rspec-1-1.pid', locked: true)
      # The sleep keeps the probes apart: with none, the wait can run its 180 probes before the unlock.
      env = { 'REVIEW_LOOP_SLEEP' => '0.1' }
      out, status = spawn_script('wait-runs.sh', checkout, env: env) do |_stdin, out, thread|
        # The script prints its first number after its first probe, which finds the lock held.
        first = out.gets
        file.flock(File::LOCK_UN)
        [first + out.read, thread.value]
      end
      expect(status.exitstatus).to eq(0)
      expect(out.lines.first).to eq("1\n")
    end
  end

  context 'without a checkout' do
    it 'waits while pgrep names a run, and exits with 0 when it names none' do
      result = wait(answers: %w[found found none])
      expect(result.out).to eq("1\n2\n")
      expect(result.status).to eq(0)
      expect(fake_calls(dir)).to eq(['-f [r]spec'] * 3)
    end

    it 'exits with 4 when pgrep still names a run at the end of the hour' do
      # A shim that always names a run: the fake pgrep costs about three times more over the 180 tests.
      result = run_script('wait-runs.sh', env: shim_env('pgrep', "#!/bin/sh\nexit 0\n"))
      expect(result.lines.last).to eq('180')
      expect(result.status).to eq(4)
    end

    it 'sleeps REVIEW_LOOP_SLEEP seconds between two tests' do
      # The fake pgrep records the time of each call, and names a run at its first two calls only.
      env = stamps_env.merge('REVIEW_LOOP_SLEEP' => ReviewLoopScripts::SLEEP)
      result = run_script('wait-runs.sh', answers: %w[found found none], env: env)
      expect(result.out).to eq("1\n2\n")
      expect_sleeps_between(3)
    end

    it 'sleeps more than a second for an empty REVIEW_LOOP_SLEEP' do
      # A pgrep that always names a run: the wait prints its second number only after the sleep.
      env = shim_env('pgrep', "#!/bin/sh\nexit 0\n").merge('REVIEW_LOOP_SLEEP' => '')
      spawn_script('wait-runs.sh', env: env) do |_stdin, out, thread|
        expect(out.gets).to eq("1\n")
        expect(IO.select([out], nil, nil, 1)).to be_nil
        kill_script(thread)
      end
    end

    it 'keeps rspec out of its own command line, which the pgrep of Linux reads' do
      # A pgrep that reads the command line of its caller, as the pgrep of Linux does, and keeps a copy of it.
      seen = File.join(dir, 'seen')
      env = shim_env('pgrep', "#!/bin/sh\nps -ww -o args= -p \"$PPID\" | tee -a \"$SEEN\" | grep -Eq -- \"$2\"\n")
      result = run_script('wait-runs.sh', env: env.merge('SEEN' => seen))
      expect(result.out).to eq('')
      expect(result.status).to eq(0)
      expect(File.read(seen)).to include('ruby')
    end
  end

  it 'exits with 2 with two arguments' do
    expect(wait('a', 'b').status).to eq(2)
  end
end
