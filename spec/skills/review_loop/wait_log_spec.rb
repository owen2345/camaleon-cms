# frozen_string_literal: true

# The wait for the end of a background task (docs/ai/testing.md, Long commands).
RSpec.describe 'scripts/wait-log.sh' do
  include ReviewLoopScripts

  let(:log) { File.join(dir, 'task.output') }

  def wait(env: {})
    run_script('wait-log.sh', log, env: env)
  end

  # Sets the last change of the log back by the minutes.
  def age(minutes)
    FileUtils.touch(log, mtime: minutes.minutes.ago.to_time)
  end

  it 'prints end, the summary line and the last three lines of an ended run' do
    File.write(log, "Randomized with seed 1\n...\n\n3 examples, 1 failure\n\nFailed examples:\n[exited with code 1]\n")
    result = wait
    expect(result.out).to eq("end\n3 examples, 1 failure\n\nFailed examples:\n[exited with code 1]\n")
    expect(result.status).to eq(0)
  end

  it 'prints end for a killed task' do
    File.write(log, "running\n[killed]\n")
    expect(wait.lines.first).to eq('end')
  end

  it 'prints end for an exit code of three digits' do
    File.write(log, "running\n[exited with code 137]\n")
    expect(wait.lines.first).to eq('end')
  end

  it 'prints end when the end line is not the last line' do
    File.write(log, "running\n[killed]\nrspec: terminated\n")
    expect(wait.lines.first).to eq('end')
  end

  it 'takes an end line only when it is the whole line' do
    File.write(log, "foo [killed]\n")
    age(40)
    expect(wait.lines.first).to eq('stale')
    File.write(log, "[killed] more\n")
    age(40)
    expect(wait.lines.first).to eq('stale')
  end

  it 'prints the summary line of a one-example run' do
    File.write(log, "1 example, 0 failures\n[exited with code 0]\n")
    expect(wait.out).to eq("end\n1 example, 0 failures\n1 example, 0 failures\n[exited with code 0]\n")
  end

  it 'prints end, not stale, for a log that ended an hour ago' do
    File.write(log, "running\n[exited with code 0]\n")
    age(60)
    expect(wait.lines.first).to eq('end')
  end

  it 'reads a log that holds a NUL byte' do
    File.write(log, "run\0x\n3 examples, 1 failure\n[exited with code 1]\n")
    expect(wait.out).to start_with("end\n3 examples, 1 failure\n")
  end

  it 'prints missing for a log that does not exist' do
    result = wait
    expect(result.out).to eq("missing\n")
    expect(result.err).to eq('')
    expect(result.status).to eq(0)
  end

  it 'prints stale for a log that did not change for 30 minutes' do
    File.write(log, "running\n")
    age(31)
    expect(wait.lines.first).to eq('stale')
  end

  it 'reads a log that changed 29 minutes ago until REVIEW_LOOP_BOUND seconds passed, then prints bound' do
    # A find that records each call, as a fake does: the wait calls it once per read. The clock of the script
    # counts whole seconds, so a bound of two seconds ends the wait after one to two seconds. With a sleep of
    # 0.1 seconds, that is about ten to twenty reads.
    env = shim_env('find', "#!/bin/sh\nprintf '%s\\0' \"$*\" >> \"$FAKE_CALLS\"\nexec /usr/bin/find \"$@\"\n")
    File.write(log, "running\n")
    age(29)
    result = wait(env: env.merge('REVIEW_LOOP_SLEEP' => '0.1', 'REVIEW_LOOP_BOUND' => '2'))
    expect(result.out).to eq("bound\nrunning\n")
    expect(result.status).to eq(0)
    expect(fake_calls(dir).size).to be_between(5, 25)
    expect(fake_calls(dir).first).to eq("#{log} -mmin -30")
  end

  it 'gives up at the bound, not after a count of reads, when the sleep is long' do
    # A sleep of 0.6 seconds and a bound of two seconds: the wait ends between one and 2.6 seconds. The first
    # run, on the missing log, keeps the first-run assessment of macOS out of the timed run.
    wait
    File.write(log, "running\n")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(wait(env: { 'REVIEW_LOOP_SLEEP' => '0.6', 'REVIEW_LOOP_BOUND' => '2' }).lines.first).to eq('bound')
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be_between(0.9, 4)
  end

  it 'sleeps REVIEW_LOOP_SLEEP seconds between two reads' do
    # A find that records the time of each call and ends the task at its third call. The wait sleeps between
    # the reads, and the fourth read finds the end line.
    body = "#!/bin/sh\n#{ReviewLoopScripts::STAMP}\n[ \"$(wc -l < \"$STAMPS\")\" -ge 3 ] && " \
           "echo '[exited with code 0]' >> \"$LOG\"\nexec /usr/bin/find \"$@\"\n"
    env = shim_env('find', body).merge(stamps_env, 'LOG' => log, 'REVIEW_LOOP_SLEEP' => ReviewLoopScripts::SLEEP)
    File.write(log, "running\n")
    expect(wait(env: env).lines.first).to eq('end')
    expect_sleeps_between(3)
  end

  it 'exits with 2 without a log' do
    expect(run_script('wait-log.sh').status).to eq(2)
  end
end
