# frozen_string_literal: true

# The head of the newest suite run of a branch (setup.md, CI), against a fake gh.
RSpec.describe 'scripts/ci-newest-head.sh' do
  include ReviewLoopScripts

  let(:suite) { 'Audit|Test supported versions' }

  before { skip_without_jq }

  def runs(*pairs)
    pairs.map { |sha, name| { headSha: sha, workflowName: name } }.to_json
  end

  it 'prints the head of the newest suite run' do
    answer = runs(%w[aaa Other], %w[bbb Audit], ['ccc', 'Test supported versions'])
    result = run_script('ci-newest-head.sh', 'o/p', 'fix/x', suite, env: fake_env(dir, [answer]))
    expect(result.out).to eq("bbb\n")
    expect(result.status).to eq(0)
    expect(fake_calls(dir).first)
      .to start_with('run list --repo o/p --branch fix/x --limit 100 --json headSha,workflowName --jq ')
  end

  it 'prints nothing when the branch has no suite run' do
    result = run_script('ci-newest-head.sh', 'o/p', 'fix/x', suite, env: fake_env(dir, [runs(%w[aaa Other])]))
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end

  it 'matches a suite workflow name that holds a regex character' do
    answer = runs(%w[aaa Other], ['bbb', 'Test (x)'])
    result = run_script('ci-newest-head.sh', 'o/p', 'fix/x', 'Test (x)|Audit', env: fake_env(dir, [answer]))
    expect(result.out).to eq("bbb\n")
  end

  it 'exits with the code of gh' do
    expect(run_script('ci-newest-head.sh', 'o/p', 'fix/x', suite, env: fake_env(dir, ['fail'])).status).to eq(1)
  end

  it 'exits with 2 without three arguments' do
    expect(run_script('ci-newest-head.sh', 'o/p', 'fix/x').status).to eq(2)
  end
end
