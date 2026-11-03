# frozen_string_literal: true

# The ci read of ci.md, against a fake gh that answers from a list. It prints the newest run of each suite
# workflow and the advisory notes once every suite run is completed.
RSpec.describe 'scripts/ci-status.sh' do
  include ReviewLoopScripts

  let(:suite) { 'Audit|Test supported versions' }
  let(:sha) { 'a' * 40 }
  let(:completed) do
    [run('Audit', 'completed', conclusion: 'failure', id: 1), run('Audit', 'completed', conclusion: 'success', id: 2),
     run('Test supported versions', 'completed', conclusion: 'failure', id: 5, attempt: 2),
     run('Other', 'in_progress')]
  end

  before { skip_without_jq }

  def run(name, status, conclusion: nil, id: 1, attempt: 1)
    { workflowName: name, status: status, conclusion: conclusion, databaseId: id, attempt: attempt }
  end

  def status(*answers, env: {})
    answers = answers.map { |a| a.is_a?(String) ? a : a.to_json }
    run_script('ci-status.sh', 'o/p', sha, suite, env: fake_env(dir, answers).merge(env))
  end

  it 'prints the newest run of each suite workflow when every suite run is completed, whatever the other runs do' do
    result = status(completed)
    expect(result.lines).to eq(['Audit | 2 | 1 | success', 'Test supported versions | 5 | 2 | failure'])
    expect(result.status).to eq(0)
    fields = 'workflowName,status,conclusion,databaseId,attempt'
    call = "run list --repo o/p --commit #{sha} --limit 100 --json #{fields} --jq "
    expect(fake_calls(dir).first).to start_with(call)
    expect(fake_calls(dir).size).to eq(1)
  end

  it 'prints a note for an advisory workflow whose newest run did not pass' do
    runs = completed + [run('Test ecosystem members', 'completed', conclusion: 'failure', id: 7),
                        run('Test ecosystem members', 'completed', conclusion: 'success', id: 3),
                        run('Test upcoming versions', 'completed', conclusion: 'cancelled', id: 8),
                        run('Lint', 'completed', conclusion: 'skipped', id: 9)]
    expect(status(runs).lines).to eq(['Audit | 2 | 1 | success', 'Test supported versions | 5 | 2 | failure',
                                      '# advisory Test ecosystem members failure',
                                      '# advisory Test upcoming versions cancelled'])
  end

  it 'polls while a suite run is pending' do
    result = status([run('Audit', 'completed', conclusion: 'success'), run('Test supported versions', 'in_progress')],
                    completed)
    expect(result.lines).to eq(['1 pending', 'Audit | 2 | 1 | success', 'Test supported versions | 5 | 2 | failure'])
    expect(result.status).to eq(0)
  end

  it 'sleeps REVIEW_LOOP_SLEEP seconds between two polls' do
    # A gh that records the time of each call, then answers as the fake does.
    body = "#!/bin/sh\n#{ReviewLoopScripts::STAMP}\nexec \"$FAKES/gh\" \"$@\"\n"
    env = shim_env('gh', body).merge('REVIEW_LOOP_SLEEP' => ReviewLoopScripts::SLEEP)
    pending_runs = [run('Audit', 'in_progress'), run('Test supported versions', 'completed', conclusion: 'success')]
    expect(status(pending_runs, pending_runs, completed, env: env).status).to eq(0)
    expect_sleeps_between(3)
  end

  it 'exits with 3 when a suite workflow still has no run at the eleventh poll' do
    result = status([run('Audit', 'completed', conclusion: 'success')])
    expect(result.lines).to eq((1..11).map { |i| "#{i} absent" })
    expect(result.status).to eq(3)
  end

  it 'exits with 4 when a suite run is still pending at the last poll' do
    result = status([run('Audit', 'queued'), run('Test supported versions', 'completed', conclusion: 'success')])
    expect(result.lines.size).to eq(120)
    expect(result.lines.last).to eq('120 pending')
    expect(result.status).to eq(4)
  end

  it 'exits with 5 after three failed calls of gh one after the other' do
    result = status('fail')
    expect(result.lines).to eq(['1 ', '2 ', '3 '])
    expect(result.status).to eq(5)
  end

  it 'counts the failed calls again after an answer' do
    pending_runs = [run('Audit', 'in_progress'), run('Test supported versions', 'completed', conclusion: 'success')]
    result = status('fail', 'fail', pending_runs, 'fail', 'fail', completed)
    expect(result.lines).to eq(['1 ', '2 ', '3 pending', '4 ', '5 ', 'Audit | 2 | 1 | success',
                                'Test supported versions | 5 | 2 | failure'])
    expect(result.status).to eq(0)
  end

  it 'exits with 2 without three arguments' do
    expect(run_script('ci-status.sh', 'o/p', sha).status).to eq(2)
  end

  it 'exits with 2 for a short SHA' do
    expect(run_script('ci-status.sh', 'o/p', 'abc', suite).status).to eq(2)
  end

  context 'with a suite workflow name that holds a regex character' do
    let(:suite) { 'Test (x)|Audit' }

    it 'matches the name as it is' do
      runs = [run('Audit', 'completed', conclusion: 'success', id: 2),
              run('Test (x)', 'completed', conclusion: 'success', id: 3)]
      expect(status(runs).lines).to eq(['Audit | 2 | 1 | success', 'Test (x) | 3 | 1 | success'])
    end
  end
end
