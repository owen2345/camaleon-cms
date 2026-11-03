# frozen_string_literal: true

require 'shared_specs/prose_gate'

# The message gate of procedure.md, Ledger rows: a subject line and at most three sentences of at most 25 words.
RSpec.describe 'scripts/message-gate.rb' do
  include ReviewLoopScripts

  def gate(message, env: {})
    path = File.join(dir, 'message')
    File.write(path, message)
    run_script('message-gate.rb', path, env: env)
  end

  def gate_text(sentence)
    "Subject\n\n#{sentence}\n"
  end

  it_behaves_like 'a prose gate', ': '

  it 'passes a subject and three sentences' do
    result = gate("Subject\n\nOne is here. Two is here. Three is here.\n")
    expect(result.status).to eq(0)
  end

  it 'does not count a subject that ends in a period' do
    expect(gate("Subject.\n\nOne is here. Two is here. Three is here.\n").status).to eq(0)
  end

  it 'prints the count of four sentences after the subject' do
    result = gate("Subject\n\nOne is here. Two is here.\n\nThree is here. Four is here.\n")
    expect(result.out).to eq("4 sentences\n")
    expect(result.status).to eq(1)
  end

  it 'does not count a trailer after the three sentences' do
    result = gate("Subject\n\nOne is here. Two is here. Three is here.\n\nCo-Authored-By: Spec <spec@example.com>\n")
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end

  it 'counts a sentence that ends in a question mark' do
    result = gate("Subject\n\nIs one here? Is two here? Is three here? Is four here?\n")
    expect(result.out).to eq("4 sentences\n")
    expect(result.status).to eq(1)
  end

  it 'counts a sentence that ends in two stars' do
    result = gate("Subject\n\n**One is here.** Two is here. Three is here. **Four is here.**\n")
    expect(result.out).to eq("4 sentences\n")
    expect(result.status).to eq(1)
  end

  it 'splits a long sentence that ends in two stars from the next one' do
    result = gate("Subject\n\n**#{words(26)}.** Two is here.\n")
    expect(result.out).to eq("26: **#{words(26)}.\n")
  end

  it 'reads the file as UTF-8 under a locale that is not UTF-8' do
    result = gate(gate_text(accented_sentence), env: ReviewLoopScripts::C_LOCALE)
    expect(result.out).to eq("26: #{accented_sentence}\n")
    expect(result.status).to eq(1)
  end

  it 'exits with 2 without a file' do
    result = run_script('message-gate.rb')
    expect(result.err).to start_with('Usage:')
    expect(result.status).to eq(2)
  end

  it 'exits with 2 for a file that it cannot read' do
    result = run_script('message-gate.rb', File.join(dir, 'none'))
    expect(result.err).to include('No such file')
    expect(result.status).to eq(2)
  end
end
