# frozen_string_literal: true

require 'shared_specs/prose_gate'

# The Markdown gate of docs/ai/prose.md: 25 words at most in an added sentence of a unified diff, and six
# sentences at most in a paragraph that holds an added line, or a removed line between two of its lines.
RSpec.describe 'scripts/markdown-gate.rb' do
  include ReviewLoopScripts

  # A unified diff that adds the lines. A line that starts with a space (context), an at sign (hunk header), a
  # backslash (a marker such as the one for no newline at the end) or a plus (added) is given as is. A line that
  # starts with a minus and a non-space, or a lone minus (removed), is given as is too.
  # A line of "- " is an added list item. The match reads bytes, so a line with an invalid UTF-8 byte does not
  # raise. The symbol :empty gives an empty line, the blank context line of some diff tools. Each hunk header gets
  # the counts of the lines of its hunk, as a diff tool writes them.
  def diff(*lines)
    body = lines.map do |l|
      next '' if l == :empty

      l.b.match?(/\A(?:[ @+\\]|-(?:\S|\z))/) ? l : "+#{l}"
    end
    "--- a/doc.md\n+++ b/doc.md\n#{with_counts(['@@ -1 +1 @@', *body]).join("\n")}\n"
  end

  def with_counts(lines)
    lines.slice_before { |l| l.start_with?('@@') }.flat_map do |header, *hunk|
      old = hunk.count { |l| l.empty? || l.b.match?(/\A[ -]/) }
      new = hunk.count { |l| l.empty? || l.b.match?(/\A[ +]/) }
      [header.sub(/\A@@ -(\d+)\S* \+(\d+)\S*/) { "@@ -#{Regexp.last_match(1)},#{old} +#{Regexp.last_match(2)},#{new}" },
       *hunk]
    end
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

  # Only a fence of the same character, at least as long and with no info string, closes a fenced block.
  describe 'a fence line inside a fenced block' do
    it 'keeps the block open at a fence of the other character' do
      expect(gate(diff('```text', '~~~', "#{words(30)}.", '```')).status).to eq(0)
    end

    it 'keeps the block open at a shorter fence' do
      expect(gate(diff('````text', '```', "#{words(30)}.", '````')).status).to eq(0)
    end

    it 'keeps the block open at a fence with an info string' do
      expect(gate(diff('```text', '```ruby', "#{words(30)}.", '```')).status).to eq(0)
    end

    it 'closes the block at a longer fence' do
      result = gate(diff('```text', '````', "#{words(26)}."))
      expect(result.out).to start_with('26 words: ')
      expect(result.status).to eq(1)
    end
  end

  it 'reads a line that starts with a code span of three backticks as text' do
    result = gate(diff("``` `x` ``` #{words(25)}."))
    expect(result.out).to start_with('26 words: X ')
    expect(result.status).to eq(1)
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

  it 'ends an added sentence at a context line and at a list item' do
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

  it 'ends an added sentence at a removed line' do
    expect(gate(diff(words(13), "-#{words(30)}.", "#{words(13, first: 'x14')}.")).status).to eq(0)
  end

  it 'leaves a fenced block at a hunk header' do
    result = gate(diff('```text', words(30), '@@ -9 +9 @@', "#{words(26)}."))
    expect(result.out).to start_with('26 words: ')
    expect(result.status).to eq(1)
  end

  # A hunk that starts after line 1 can start inside a fenced block, so the gate cannot tell whether a fence of
  # the hunk opens or closes a block.
  describe 'a fence in a hunk that starts after line 1' do
    it 'refuses a fence on an added line' do
      result = gate(diff('@@ -74 +74 @@', '```', 'One added sentence.'))
      expect(result.out).to eq("fence in a hunk from line 74: run the diff with -U99999\n")
      expect(result.status).to eq(1)
    end

    it 'refuses a fence on a context line, once a hunk' do
      result = gate(diff('@@ -74 +74 @@', ' ```', ' ```', 'One added sentence.'))
      expect(result.out).to eq("fence in a hunk from line 74: run the diff with -U99999\n")
      expect(result.status).to eq(1)
    end

    it 'ignores a removed fence' do
      expect(gate(diff('@@ -74 +74 @@', '-```', 'One added sentence.')).status).to eq(0)
    end

    it 'passes a fence in the next hunk when it starts at line 1' do
      expect(gate(diff('@@ -74 +74 @@', 'One added sentence.', '@@ -1 +1 @@', '```', "#{words(30)}.", '```')).status)
        .to eq(0)
    end
  end

  it 'keeps a fenced block across a context line' do
    expect(gate(diff('```text', ' context', "#{words(30)}.", '```')).status).to eq(0)
  end

  it 'reads a fence on a context line' do
    expect(gate(diff(' ```text', "#{words(30)}.", ' ```')).status).to eq(0)
  end

  describe 'a paragraph with context lines' do
    def sentences(range)
      range.map { |i| "Sentence #{i} is here." }
    end

    def context(range)
      sentences(range).map { |s| " #{s}" }
    end

    # An edit that splits one sentence in a paragraph of six sentences gives it seven. The added lines alone
    # hold two of them.
    it 'counts the context lines of a paragraph that holds an added line' do
      result = gate(diff(*context(1..5), sentences(6..7).join(' ')))
      expect(result.out).to eq("7 sentences: #{sentences(1..7).join(' ')[0, 70]}\n")
      expect(result.status).to eq(1)
    end

    it 'counts the paragraph across a removed line' do
      result = gate(diff(*context(1..3), '-Old text.', sentences(4..7).join(' ')))
      expect(result.out).to start_with('7 sentences: ')
      expect(result.status).to eq(1)
    end

    # A removed heading or a removed blank line between two paragraphs joins them, with no added line.
    it 'counts a paragraph that a removed heading joined' do
      result = gate(diff(*context(1..3), '-## Old heading', *context(4..7)))
      expect(result.out).to eq("7 sentences: #{sentences(1..7).join(' ')[0, 70]}\n")
      expect(result.status).to eq(1)
    end

    it 'counts a paragraph that a removed blank line joined' do
      result = gate(diff(*context(1..3), '-', *context(4..7)))
      expect(result.out).to eq("7 sentences: #{sentences(1..7).join(' ')[0, 70]}\n")
      expect(result.status).to eq(1)
    end

    it 'does not count a paragraph after a removed paragraph' do
      expect(gate(diff(*context(1..2), ' ', '-Old paragraph.', '-## Old heading', *context(3..9))).status).to eq(0)
    end

    it 'counts the last paragraph across the marker of no newline at the end' do
      marker = '\ No newline at end of file'
      result = gate(diff(*context(1..5), '-Old end.', marker, sentences(6..7).join(' '), marker))
      expect(result.out).to start_with('7 sentences: ')
      expect(result.status).to eq(1)
    end

    it 'counts the paragraph across a removed rule line' do
      result = gate(diff(*context(1..3), '----', sentences(4..7).join(' ')))
      expect(result.out).to start_with('7 sentences: ')
      expect(result.status).to eq(1)
    end

    it 'keeps a fenced block across a removed rule line' do
      expect(gate(diff(' ```text', '----', "#{words(30)}.", ' ```')).status).to eq(0)
    end

    # The diff line of a removed "-- x" starts like the header of the old file.
    it 'counts the paragraph after a fenced block that lost a line that starts with "-- "' do
      result = gate(diff(' ```sql', '--- old comment', ' ```', sentences(1..7).join(' ')))
      expect(result.out).to start_with('7 sentences: ')
      expect(result.status).to eq(1)
    end

    # The diff line of an added "++ x" starts like the header of the new file.
    it 'keeps a fenced block across an added line that starts with "++ "' do
      expect(gate(diff(' ```text', '+++ x', "#{words(30)}.", ' ```')).status).to eq(0)
    end

    it 'does not count a paragraph with no added line' do
      expect(gate(diff(*context(1..7), ' ', 'One added sentence.')).status).to eq(0)
    end

    it 'ends the paragraph at a blank context line' do
      expect(gate(diff(*context(1..4), ' ', sentences(5..7).join(' '))).status).to eq(0)
    end

    # A gate that reads the empty line as a header ends the hunk and prints nothing. A gate that reads it as text
    # counts eleven sentences.
    it 'ends the paragraph at an empty line, the blank context line of some diff tools' do
      result = gate(diff(*context(1..4), :empty, sentences(5..11).join(' ')))
      expect(result.out).to eq("7 sentences: #{sentences(5..11).join(' ')[0, 70]}\n")
      expect(result.status).to eq(1)
    end

    # A diff tool that compares two files writes no line before the header of the next diff.
    it 'ends a hunk after its last line, before the header of the next diff' do
      text = "#{diff('One added sentence.', ' ', *context(1..6))}--- a/b.md\n+++ b/b.md\n@@ -1 +1 @@\n-x\n+y\n"
      expect(gate(text).status).to eq(0)
    end

    it 'ends the paragraph at a hunk header' do
      expect(gate(diff(*context(1..4), '@@ -9 +9 @@', sentences(5..7).join(' '))).status).to eq(0)
    end

    it 'prints no sentence of a context line over 25 words' do
      expect(gate(diff(" #{words(30)}.", 'One added sentence.')).status).to eq(0)
    end
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
