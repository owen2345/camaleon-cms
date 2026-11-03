# frozen_string_literal: true

# The second read of a pass (procedure.md, Pass start): the state lines of this run and the lines after its
# last PASS line.
RSpec.describe 'scripts/run-state.sh' do
  include ReviewLoopScripts

  let(:pass_line) do
    'PASS 1/8 camaleon-cms PR 9 | HEAD 2222 → 3333 | git status: clean | rspec: n/a | ' \
      'checks: rubocop ok, ci n/a (x | y) | fixed: 1 correctness/security, 0 other | step 6: on | ' \
      'deferred 0, repeat 0, decision 1, conflict 0 | UNSETTLED | continue'
  end
  let(:ledger) do
    <<~LEDGER
      ## Run 2026-10-01, effort max
      setup HEAD 1111 | /co | o/p | head | origin/master | none
      PASS 1/8 camaleon-cms PR 9 | HEAD 1111 → 2222 | git status: clean | CLEAN | STOP: converged, pushed
      ## Run 2026-10-02, effort max
      setup HEAD 2222 | /co | o/p | head | origin/master | none
      task abc /log ci poll
      ci 2222 ok
      1 | claim a | lib/a.rb#m | correctness | FIXED | 3333
      1 | claim b | doc.md Section | wording | DECISION | needs the user
      review
      #{pass_line}
      2 | claim c | lib/c.rb#o | wording | FIXED | 4444
      review
      todo claim d | doc.md Other | wording
    LEDGER
  end

  it 'prints the state lines of this run and every line after its last PASS line' do
    write_ledger(ledger)
    result = run_script('run-state.sh', ledger_path)
    expect(result.lines).to eq([
                                 '## Run 2026-10-02, effort max',
                                 'setup HEAD 2222 | /co | o/p | head | origin/master | none',
                                 'ci 2222 ok',
                                 '1 | lib/a.rb#m | correctness',
                                 'PASS 1/8 camaleon-cms PR 9 | HEAD 2222 → 3333 | UNSETTLED',
                                 '2 | claim c | lib/c.rb#o | wording | FIXED | 4444',
                                 'review',
                                 'todo claim d | doc.md Other | wording'
                               ])
    expect(result.status).to eq(0)
  end

  it 'prints every line of a run that has no PASS line yet' do
    lines = ['## Run 1', 'setup HEAD 1111 | /co | o/p | head | origin/master | none', 'task abc /log cmd',
             '1 | claim a | lib/a.rb#m | wording | FIXED | 2222', 'review']
    write_ledger(lines.map { |l| "#{l}\n" }.join)
    expect(run_script('run-state.sh', ledger_path).lines).to eq(lines)
  end

  it 'compacts only a row whose verdict is FIXED' do
    row = '1 | the row was FIXED | lib/a.rb#m | wording | REFUTED | FIXED in 2222, judged at 3333'
    write_ledger("## Run 1\n#{row}\nPASS 1/8 x | HEAD 1111 → 3333 | UNSETTLED | continue\n")
    expect(run_script('run-state.sh',
                      ledger_path).lines).to eq(['## Run 1', 'PASS 1/8 x | HEAD 1111 → 3333 | UNSETTLED'])
  end

  it 'reads a row that holds an invalid UTF-8 byte under a UTF-8 locale' do
    write_ledger("## Run 1\n1 | bad \xFF byte | lib/x.rb | wording | FIXED | 3333\n" \
                 "PASS 1/8 x | HEAD 1111 → 3333 | UNSETTLED | continue\n")
    result = run_script('run-state.sh', ledger_path, env: ReviewLoopScripts::UTF8_LOCALE)
    expect(result.lines).to eq(['## Run 1', '1 | lib/x.rb | wording', 'PASS 1/8 x | HEAD 1111 → 3333 | UNSETTLED'])
  end

  it 'exits with 2 without a ledger' do
    expect(run_script('run-state.sh').status).to eq(2)
  end
end
