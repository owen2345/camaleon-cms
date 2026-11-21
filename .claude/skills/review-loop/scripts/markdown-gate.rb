#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: <unified diff> | markdown-gate.rb
#
# The Markdown gate of docs/ai/prose.md. It reads a unified diff as UTF-8, on its standard input or from the
# files that it gets as arguments. It prints each added sentence over 25 words, and each paragraph that holds
# an added line and has more than six sentences. It counts the context lines of such a paragraph too, so a diff with no
# context (-U0) gives it only the added lines. A code span counts as one word. It does not test a table row, a
# heading or a fenced block. It exits with 1 when it printed a line, else with 0, and with 2 for a file that it
# cannot read.

require_relative 'prose'

LIST_MARK = /\A\s*(?:[-*+]|\d+\.)\s+/

bad = false
# The added lines since the last line that is not added. Their sentences have the limit of 25 words.
added = []
# The lines of the paragraph in the new text, the context lines included. The paragraph has the limit of six
# sentences when it holds an added line (touched).
paragraph = []
touched = false
fenced = false

check_added = lambda do
  next if added.empty?

  lines = ReviewLoopProse.report(ReviewLoopProse.sentences(added.join(' ')), ' words: ', width: 70)
  added = []
  puts lines
  bad ||= lines.any?
end

check = lambda do
  check_added.call
  text = paragraph.join(' ')
  counted = touched
  paragraph = []
  touched = false
  next unless counted

  sentences = ReviewLoopProse.sentences(text)
  next if sentences.size <= 6

  bad = true
  puts "#{sentences.size} sentences: #{text[0, 70]}"
end

# The kind of a line of the diff: :added, :context (an empty line too, which some diff tools write for a blank
# context line), :removed, :marker for a line such as "\ No newline at end of file", or :other for a header. A
# file header has a space after its three marks, so a removed rule line ("----") is a removed line.
kind_of = lambda do |line|
  if line.match?(/\A\+(?!\+\+ )/) then :added
  elsif line.empty? || line.start_with?(' ') then :context
  elsif line.match?(/\A-(?!-- )/) then :removed
  elsif line.start_with?('\\') then :marker
  else :other
  end
end

begin
  ARGF.set_encoding(Encoding::UTF_8)
  ARGF.each_line do |line|
    line = line.scrub.chomp
    kind = kind_of.call(line)
    # A marker line is not in the text: it ends nothing.
    next if kind == :marker

    # A removed line is not in the new text: it ends the added lines, not the paragraph. A header ends the
    # paragraph and any fenced block, because the diff does not hold the lines between two hunks.
    check_added.call unless kind == :added
    next if kind == :removed

    if kind == :other
      check.call
      fenced = false
      next
    end

    s = line[1..].to_s.sub(/\A\s*>\s?/, '')
    if s.match?(/\A\s*(```|~~~)/)
      check.call
      fenced = !fenced
      next
    end
    next if fenced

    if s.strip.empty? || s.match?(/\A\s*(\||#+\s|---)/)
      check.call
      next
    end
    check.call if s.sub!(LIST_MARK, '')
    s = ReviewLoopProse.spans_as_words(s)
    paragraph << s
    next unless kind == :added

    added << s
    touched = true
  end
rescue SystemCallError => e
  warn e.message
  exit 2
end
check.call
exit(bad ? 1 : 0)
