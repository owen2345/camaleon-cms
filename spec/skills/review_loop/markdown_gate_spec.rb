# frozen_string_literal: true

require 'shared_specs/prose_gate'

# The Markdown gate of docs/ai/prose.md: the added sentences of a unified diff, 25 words and six sentences a
# paragraph at most.
RSpec.describe 'scripts/markdown-gate.rb' do
  include ReviewLoopScripts

  # A unified diff that adds the lines. A line that starts with a space (context), an at sign (hunk header) or a
  # plus (added) is given as is. A line that starts with a minus and a non-space (removed) is given as is too.
  # A line of "- " is an added list item. The match reads bytes, so a line with an invalid UTF-8 byte does not
  # raise.
  def diff(*lines)
    body = lines.map { |l| l.b.match?(/\A(?:[ @+]|-\S)/) ? l : "+#{l}" }.join("\n")
    "--- a/doc.md\n+++ b/doc.md\n@@ -1 +1 @@\n#{body}\n"
  end

  def gate(text, env: {})
    run_script('markdown-gate.rb', stdin: text, env: env)
  end

  def gate_text(sentence)
    diff(sentence)
  end

  it_behaves_like 'a prose gate', ' words: '

  it 'does not test a heading' do
    expect(gate(diff("# #{words(30)}")).status).to eq(0)
  end

  it 'does not test a table row' do
    expect(gate(diff("| #{words(30)} | x |")).status).to eq(0)
  end

  it 'does not test a fenced block' do
    expect(gate(diff('```text', "#{words(30)}.", '```')).status).to eq(0)
  end

  it 'does not test a fenced block with tildes' do
    expect(gate(diff('~~~', "#{words(30)}.", '~~~')).status).to eq(0)
  end

  it 'strips the blockquote marker before it counts' do
    expect(gate(diff("> #{words(25)}.")).status).to eq(0)
  end

  it 'joins a hard-wrapped paragraph before it counts' do
    result = gate(diff(words(13), "#{words(13, first: 'x14')}."))
    expect(result.out).to start_with('26 words: ')
    expect(result.status).to eq(1)
  end

  it 'prints a paragraph of seven sentences' do
    sentences = (1..7).map { |i| "Sentence #{i} is here." }.join(' ')
    result = gate(diff(sentences))
    expect(result.out).to eq("7 sentences: #{sentences[0, 70]}\n")
    expect(result.status).to eq(1)
  end

  it 'passes a paragraph of six sentences' do
    expect(gate(diff((1..6).map { |i| "Sentence #{i} is here." }.join(' '))).status).to eq(0)
  end

  it 'ends a paragraph at a context line and a list item' do
    result = gate(diff(words(13), " #{words(20)}", "#{words(13)}.", "- #{words(13)}", "- #{words(13)}."))
    expect(result.status).to eq(0)
  end

  it 'ends a paragraph at a numbered item' do
    expect(gate(diff(*(1..4).map { |i| "#{i}. #{words(12)}." })).status).to eq(0)
  end

  it 'ends a paragraph at a rule line' do
    expect(gate(diff(words(13), '+---', "#{words(13, first: 'x14')}.")).status).to eq(0)
  end

  it 'strips every blank after a list marker from the excerpt' do
    result = gate(diff("-   #{words(26)}."))
    expect(result.out).to eq("26 words: #{"#{words(26)}."[0, 70]}\n")
  end

  it 'ends a paragraph at a removed line' do
    expect(gate(diff(words(13), "-#{words(30)}.", "#{words(13, first: 'x14')}.")).status).to eq(0)
  end

  it 'leaves a fenced block at a line that is not added' do
    result = gate(diff('```text', words(30), ' context', "#{words(26)}."))
    expect(result.out).to start_with('26 words: ')
    expect(result.status).to eq(1)
  end

  it 'tests only the added lines' do
    expect(gate(diff("-#{words(30)}.", " #{words(30)}.")).status).to eq(0)
  end

  it 'reads the diff as UTF-8 under a locale that is not UTF-8' do
    # A byte read turns each accented letter into "??", and the sentence then ends at "résumé".
    result = gate(diff(accented_sentence), env: ReviewLoopScripts::C_LOCALE)
    expect(result.out).to eq("26 words: #{accented_sentence[0, 70]}\n")
    expect(result.status).to eq(1)
  end

  it 'exits with 2 for a file that it cannot read' do
    result = run_script('markdown-gate.rb', File.join(dir, 'none.diff'))
    expect(result.err).to include('No such file')
    expect(result.status).to eq(2)
  end
end
