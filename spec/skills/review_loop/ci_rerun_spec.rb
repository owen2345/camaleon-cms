# frozen_string_literal: true

# The one rerun of a workflow run (ci.md), against a fake gh that answers from a list. The header of the script
# gives its flow and its exit codes.
RSpec.describe 'scripts/ci-rerun.sh' do
  include ReviewLoopScripts

  let(:refused) { 'fail:run 77 cannot be rerun; Unable to retry this workflow run' }
  let(:running) { 'fail:run 77 cannot be rerun; This workflow is already running' }
  let(:not_found) { 'fail:failed to rerun: HTTP 404: Not Found (https://api.github.com/repos/o/p/actions/runs/77)' }
  let(:conflict) { 'fail:failed to rerun: HTTP 409: Conflict (https://api.github.com/repos/o/p/actions/runs/77)' }
  let(:bad_gateway) { 'fail:failed to rerun: HTTP 502: Bad Gateway (https://api.github.com/repos/o/p/actions/runs/77)' }
  let(:rerun_failed) { 'run rerun 77 --repo o/p --failed' }
  let(:rerun_all) { 'run rerun 77 --repo o/p' }
  let(:view) { 'run view 77 --repo o/p --json attempt --jq .attempt' }

  before { skip_without_jq }

  def attempt(number)
    { attempt: number }
  end

  # Runs the script for run 77, with the attempt before the rerun. The first answer is for the read before
  # the rerun.
  def rerun(*answers, before: 1, env: {})
    run_script('ci-rerun.sh', 'o/p', '77', before.to_s, answers: answers, env: env)
  end

  it 'reruns the failed jobs and exits with 0 once the attempt of the run is above the attempt before the rerun' do
    result = rerun(attempt(1), 'ok', attempt(1), attempt(2))
    expect(result.lines).to eq(['0 1', '1 1', '2 2'])
    expect(result.status).to eq(0)
    expect(fake_calls(dir)).to eq([view, rerun_failed, view, view])
  end

  it 'asks GitHub for no rerun when the run already shows a higher attempt' do
    result = rerun(attempt(10), before: 9)
    expect(result.lines).to eq(['0 10'])
    expect(result.status).to eq(0)
    expect(fake_calls(dir)).to eq([view])
  end

  it 'reruns the whole run when GitHub refuses the rerun of the failed jobs' do
    result = rerun(attempt(1), refused, 'ok', attempt(2))
    expect(result.lines).to eq(['0 1', '1 2'])
    expect(result.err).to include('cannot be rerun')
    expect(result.status).to eq(0)
    expect(fake_calls(dir)).to eq([view, rerun_failed, rerun_all, view])
  end

  it 'takes an HTTP 4xx status as a refusal, with or without a message after it' do
    expect(rerun(attempt(1), not_found, 'ok', attempt(2)).status).to eq(0)
    expect(fake_calls(dir)).to eq([view, rerun_failed, rerun_all, view])
    expect(rerun(attempt(1), 'fail:failed to rerun: HTTP 404 (https://x)', 'ok', attempt(2)).status).to eq(0)
  end

  it 'exits with 1 when GitHub refuses the rerun of the whole run too' do
    result = rerun(attempt(1), refused, conflict)
    expect(result.lines).to eq(['0 1'])
    expect(result.err).to include('cannot be rerun', 'HTTP 409')
    expect(result.status).to eq(1)
    expect(fake_calls(dir)).to eq([view, rerun_failed, rerun_all])
  end

  it 'takes a refusal because the run is already running as an accepted rerun, and reads the attempt' do
    result = rerun(attempt(1), running, attempt(1), attempt(2))
    expect(result.lines).to eq(['0 1', '1 1', '2 2'])
    expect(result.err).to include('already running')
    expect(result.status).to eq(0)
    expect(fake_calls(dir)).to eq([view, rerun_failed, view, view])
  end

  it 'exits with 4 when the run is already running and its attempt does not rise in six reads' do
    result = rerun(attempt(1), running, attempt(1))
    expect(result.lines).to eq(['0 1'] + (1..6).map { |i| "#{i} 1" })
    expect(result.status).to eq(4)
    expect(fake_calls(dir)).to eq([view, rerun_failed] + [view] * 6)
  end

  it 'exits with 5 when gh fails for a reason other than a refusal' do
    result = rerun(attempt(1), bad_gateway)
    expect(result.err).to include('HTTP 502')
    expect(result.status).to eq(5)
    expect(fake_calls(dir)).to eq([view, rerun_failed])
    expect(rerun(attempt(1), 'fail').status).to eq(5)
  end

  it 'exits with 5 when the rerun of the whole run fails for a reason other than a refusal' do
    result = rerun(attempt(1), refused, bad_gateway)
    expect(result.err).to include('cannot be rerun', 'HTTP 502')
    expect(result.status).to eq(5)
    expect(fake_calls(dir)).to eq([view, rerun_failed, rerun_all])
  end

  it 'exits with 5 when the read before the rerun fails or gives no number' do
    result = rerun('fail')
    expect(result.lines).to eq(['0 '])
    expect(result.status).to eq(5)
    expect(fake_calls(dir)).to eq([view])
    result = rerun(attempt('x'))
    expect(result.lines).to eq(['0 x'])
    expect(result.status).to eq(5)
  end

  it 'exits with 2 when the run shows an attempt below the attempt before the rerun' do
    result = rerun(attempt(9), before: 10)
    expect(result.lines).to eq(['0 9'])
    expect(result.err).to include('but the run shows')
    expect(result.status).to eq(2)
    expect(fake_calls(dir)).to eq([view])
  end

  it 'reads again after a failed read' do
    result = rerun(attempt(1), 'ok', 'fail', 'fail', attempt(2))
    expect(result.lines).to eq(['0 1', '1 ', '2 ', '3 2'])
    expect(result.status).to eq(0)
  end

  it 'exits with 4 when no read after the rerun shows a higher attempt in six reads' do
    result = rerun(attempt(3), 'ok', attempt(3), 'fail', before: 3)
    expect(result.lines).to eq(['0 3', '1 3'] + (2..6).map { |i| "#{i} " })
    expect(result.status).to eq(4)
    expect(fake_calls(dir).size).to eq(8)
  end

  it 'takes an attempt that is not a number as no rise, with no error output' do
    result = rerun(attempt(1), 'ok', attempt('x'), attempt(2))
    expect(result.lines).to eq(['0 1', '1 x', '2 2'])
    expect(result.err).to eq('')
    expect(result.status).to eq(0)
  end

  it 'sleeps REVIEW_LOOP_SLEEP seconds between two reads after the rerun' do
    # The fake gh records the time of each call. The first two gaps hold the read before the rerun and the
    # rerun, with no sleep. The second read fails, and the sleep follows it too.
    env = stamps_env.merge('REVIEW_LOOP_SLEEP' => ReviewLoopScripts::SLEEP)
    expect(rerun(attempt(1), 'ok', 'fail', attempt(1), attempt(2), env: env).status).to eq(0)
    expect(stamp_gaps.size).to eq(4)
    expect(stamp_gaps.drop(2)).to all(be >= ReviewLoopScripts::SLEEP.to_f)
  end

  it 'sleeps more than a second for an empty REVIEW_LOOP_SLEEP' do
    # A run whose attempt never rises: the line of the second read after the rerun comes only after the sleep.
    env = { 'REVIEW_LOOP_SLEEP' => '' }
    spawn_script('ci-rerun.sh', 'o/p', '77', '1', answers: [attempt(1), 'ok', attempt(1)], env: env) do |_, out, thread|
      expect(out.gets).to eq("0 1\n")
      expect(out.gets).to eq("1 1\n")
      expect(IO.select([out], nil, nil, 1)).to be_nil
      kill_script(thread)
    end
  end

  it 'exits with 2 without three arguments' do
    expect(run_script('ci-rerun.sh', 'o/p', '77').status).to eq(2)
  end

  it 'exits with 2 for a run id that is no number, or an attempt that is no number above 0, before any call of gh' do
    expect(run_script('ci-rerun.sh', 'o/p', 'x', '1', answers: ['ok']).status).to eq(2)
    expect(rerun('ok', before: '').status).to eq(2)
    expect(rerun('ok', before: 0).status).to eq(2)
    expect(fake_calls(dir)).to eq([])
  end
end
