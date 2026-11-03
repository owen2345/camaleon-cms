# frozen_string_literal: true

# The first read of a pass (procedure.md, Pass start). It prints the REFUTED, DECISION and CONFLICT rows of
# the ledger and the DEFERRED rows of this run, each with the HEAD of the row.
RSpec.describe 'scripts/verdicts.sh' do
  include ReviewLoopScripts

  let(:first_head) { 'a' * 40 }
  let(:second_head) { 'b' * 40 }
  let(:ledger) do
    <<~LEDGER
      0 | seed decision | doc.md Section | wording | DECISION | user 2026-10-07: keep it
      0 | seed refuted | lib/a.rb#m | correctness | REFUTED | the code guards it, judged at abc123abc123
      ## Run 2026-10-01, effort max
      setup HEAD #{first_head} | /co | o/p | head | origin/master | none
      1 | one judged | lib/b.rb#n | correctness | REFUTED | not so, judged at 111111111111
      1 | two judged | doc.md Other | wording | DEFERRED | PLAUSIBLE judged at 222222222222; again judged at 333333333333
      1 | fixed claim | lib/c.rb#o | correctness | FIXED | 444444444444
      1 | run one deferred | lib/d.rb#p | wording | DEFERRED | PLAUSIBLE
      PASS 1/8 camaleon-cms PR 9 | HEAD aaaaaaaaaaaa → 444444444444 | git status: clean | UNSETTLED | continue
      ## Run 2026-10-02, effort max
      setup HEAD #{second_head} | /co | o/p | head | origin/master | none
      2 | conflict judged | lib/e.rb#q | conventions | CONFLICT | contradicts a row, judged at 555555555555
      2 | deferred now | doc.md Third | wording | DEFERRED | PLAUSIBLE, cannot confirm
      2 | decision now | doc.md Third | wording | DECISION | needs the user
    LEDGER
  end

  it 'prints the rows with the HEAD of each, then the DEFERRED rows of this run' do
    write_ledger(ledger)
    result = run_script('verdicts.sh', ledger_path)
    expect(result.lines).to eq([
                                 '0 | seed refuted | lib/a.rb#m | REFUTED | abc123abc123',
                                 "0 | seed decision | doc.md Section | DECISION | #{first_head}",
                                 '1 | one judged | lib/b.rb#n | REFUTED | 111111111111',
                                 '2 | conflict judged | lib/e.rb#q | CONFLICT | 555555555555',
                                 "2 | decision now | doc.md Third | DECISION | #{second_head}",
                                 "2 | deferred now | doc.md Third | DEFERRED | #{second_head}"
                               ])
    expect(result.status).to eq(0)
  end

  it 'takes the last judged at of a row' do
    write_ledger(ledger.sub('DEFERRED | PLAUSIBLE judged at 222222222222; again judged at 333333333333',
                            'REFUTED | judged at 222222222222; again judged at 333333333333'))
    expect(run_script('verdicts.sh',
                      ledger_path).lines).to include('1 | two judged | doc.md Other | REFUTED | 333333333333')
  end

  it 'reads a row that holds an invalid UTF-8 byte under a UTF-8 locale' do
    write_ledger("## Run 1\n1 | bad \xFF byte | lib/x.rb | wording | REFUTED | no, judged at 111111111111\n")
    result = run_script('verdicts.sh', ledger_path, env: ReviewLoopScripts::UTF8_LOCALE)
    expect(result.out).to eq("1 | bad \xFF byte | lib/x.rb | REFUTED | 111111111111\n")
  end

  it 'exits with 2 without a ledger' do
    expect(run_script('verdicts.sh').status).to eq(2)
  end
end
