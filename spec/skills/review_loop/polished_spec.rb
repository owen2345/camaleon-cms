# frozen_string_literal: true

# The <after> of the newest PASS line of a pass whose review ran (setup.md, Ledger), or none.
RSpec.describe 'scripts/polished.sh' do
  include ReviewLoopScripts

  let(:first) { init_repo(dir) }
  let(:second) { commit(dir, { 'b.txt' => "b\n" }, 'second') }
  let(:first_pass) { "PASS 1/8 camaleon-cms PR 9 | HEAD 1111 → #{first} | UNSETTLED | continue" }
  let(:second_pass) { "PASS 2/8 camaleon-cms PR 9 | HEAD #{first} → #{second[0, 12]} | SETTLED | continue" }

  def polished(*lines, env: {})
    write_ledger(lines.map { |l| "#{l}\n" }.join)
    run_script('polished.sh', ledger_path, dir, env: env)
  end

  it 'prints the after of the newest PASS line that a review line precedes' do
    expect(polished('review', first_pass, 'review', second_pass).out).to eq("#{second[0, 12]}\n")
  end

  it 'skips a PASS line of a pass with no review' do
    expect(polished('review', first_pass, second_pass).out).to eq("#{first}\n")
  end

  it 'takes only a line that is exactly review as a review line' do
    expect(polished('reviewed the task', 'a pass under review', first_pass).out).to eq("none\n")
  end

  it 'takes only a PASS line that starts its line, of a pass 1 to 8' do
    expect(polished('review', "Previous: #{first_pass}").out).to eq("none\n")
    expect(polished('review', first_pass.sub('PASS 1/8', 'PASS 9/8')).out).to eq("none\n")
    expect(polished('review', first_pass.sub('PASS 1/8', 'PASS 8/8')).out).to eq("#{first}\n")
  end

  it 'skips a PASS 0/8 line' do
    expect(polished('review',
                    "PASS 0/8 camaleon-cms PR 9 | HEAD #{first} → #{first} | STOP: setup").out).to eq("none\n")
  end

  it 'counts a PASS line that a STOP quotes once' do
    expect(polished('review', first_pass, 'review', first_pass, second_pass).out).to eq("#{second[0, 12]}\n")
  end

  it 'prints none, with no error, when the checkout lacks the commit' do
    init_repo(dir)
    line = 'PASS 1/8 camaleon-cms PR 9 | HEAD 111111111111 → 222222222222 | UNSETTLED | continue'
    result = polished('review', line)
    expect(result.out).to eq("none\n")
    expect(result.err).to eq('')
  end

  it 'reads a PASS line that holds an invalid UTF-8 byte under a UTF-8 locale' do
    line = "PASS 1/8 camaleon-cms PR 9 | HEAD 1111 → #{first} | git status: \xFF | UNSETTLED | continue"
    expect(polished('review', line, env: ReviewLoopScripts::UTF8_LOCALE).out).to eq("#{first}\n")
  end

  it 'prints none for a ledger with no such line' do
    result = polished('0 | seed | x | wording | DECISION | user')
    expect(result.out).to eq("none\n")
    expect(result.status).to eq(0)
  end

  it 'exits with the code of awk for a ledger that it cannot read' do
    result = run_script('polished.sh', File.join(dir, 'none.md'), dir)
    expect(result.out).to eq('')
    expect(result.status).to eq(2)
  end

  it 'exits with 2 without a checkout' do
    write_ledger('')
    expect(run_script('polished.sh', ledger_path).status).to eq(2)
  end
end
