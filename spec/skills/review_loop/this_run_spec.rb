# frozen_string_literal: true

# The lines of the last run of a ledger, from its header on (procedure.md, Pass start).
RSpec.describe 'scripts/this-run.sh' do
  include ReviewLoopScripts

  it 'prints the lines from the last run header on' do
    write_ledger("0 | seed | x | wording | DECISION | user\n## Run 1\nsetup HEAD aaa\nPASS 1/8 x\n" \
                 "## Run 2\nsetup HEAD bbb\n1 | c | l | wording | FIXED | sha\n")
    result = run_script('this-run.sh', ledger_path)
    expect(result.out).to eq("## Run 2\nsetup HEAD bbb\n1 | c | l | wording | FIXED | sha\n")
    expect(result.status).to eq(0)
  end

  it 'reads a ledger that holds a NUL byte' do
    ledger = "## Run 1\nx\0y\n"
    expect(run_script('this-run.sh', write_ledger(ledger)).out).to eq(ledger)
  end

  it 'prints nothing and exits with 1 without a run header' do
    write_ledger("0 | seed | x | wording | DECISION | user\n")
    result = run_script('this-run.sh', ledger_path)
    expect(result.out).to eq('')
    expect(result.status).to eq(1)
  end

  it 'exits with 2 without a ledger' do
    expect(run_script('this-run.sh').status).to eq(2)
  end
end
