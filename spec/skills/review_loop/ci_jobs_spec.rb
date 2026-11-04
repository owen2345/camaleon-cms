# frozen_string_literal: true

# The jobs of a workflow run that did not pass (ci.md), against a fake gh.
RSpec.describe 'scripts/ci-jobs.sh' do
  include ReviewLoopScripts

  let(:jobs) do
    { jobs: [
      { databaseId: 1, conclusion: 'success', name: 'lint', steps: [] },
      { databaseId: 2, conclusion: 'failure', name: 'spec (3.4, rails_8)',
        steps: [{ conclusion: 'success' }, { conclusion: 'failure' }, { conclusion: 'failure' }] },
      { databaseId: 3, conclusion: 'cancelled', name: 'spec (3.2, rails_7)', steps: [{ conclusion: 'cancelled' }] },
      { databaseId: 4, conclusion: 'skipped', name: 'release', steps: [] }
    ] }
  end

  before { skip_without_jq }

  it 'prints the id, the conclusion, the count of failed steps and the name of each job that did not pass' do
    result = run_script('ci-jobs.sh', 'o/p', '77', answers: [jobs])
    expect(result.lines).to eq(['2 failure 2 spec (3.4, rails_8)', '3 cancelled 0 spec (3.2, rails_7)'])
    expect(result.status).to eq(0)
    expect(fake_calls(dir).first).to start_with('run view 77 --repo o/p --json jobs --jq ')
  end

  it 'reads the jobs of an attempt' do
    run_script('ci-jobs.sh', 'o/p', '77', '2', answers: [jobs])
    expect(fake_calls(dir).first).to start_with('run view 77 --repo o/p --attempt 2 --json jobs --jq ')
  end

  it 'exits with the code of gh' do
    expect(run_script('ci-jobs.sh', 'o/p', '77', answers: ['fail']).status).to eq(1)
  end

  it 'exits with 2 without a run id' do
    expect(run_script('ci-jobs.sh', 'o/p').status).to eq(2)
  end

  it 'exits with 2 for an attempt that is not a number, before any call of gh' do
    expect(run_script('ci-jobs.sh', 'o/p', '77', '', answers: [jobs]).status).to eq(2)
    expect(run_script('ci-jobs.sh', 'o/p', '77', 'x', answers: [jobs]).status).to eq(2)
    expect(fake_calls(dir)).to eq([])
  end
end
