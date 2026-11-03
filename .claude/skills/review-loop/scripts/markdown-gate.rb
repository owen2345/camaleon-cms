#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: <unified diff> | markdown-gate.rb
#
# The Markdown gate of docs/ai/prose.md. It reads a unified diff as UTF-8, on its standard input or from the
# files that it gets as arguments. It prints each added sentence over 25 words and each added paragraph over
# six sentences. A code span counts as one word. It does not test a table row, a heading or a fenced block. It
# exits with 1 when it printed a line, else with 0, and with 2 for a file that it cannot read.

require_relative 'prose'

LIST_MARK = /\A\s*(?:[-*+]|\d+\.)\s+/

bad = false
paragraph = []
fenced = false

check = lambda do
  next if paragraph.empty?

  text = paragraph.join(' ')
  paragraph = []
  sentences = ReviewLoopProse.sentences(text)
  lines = ReviewLoopProse.report(sentences, ' words: ', width: 70)
  puts lines
  bad ||= lines.any?
  next if sentences.size <= 6

  bad = true
  puts "#{sentences.size} sentences: #{text[0, 70]}"
end

begin
  ARGF.set_encoding(Encoding::UTF_8)
  ARGF.each_line do |line|
    line = line.scrub
    unless line.match?(/\A\+(?!\+\+)/)
      check.call
      fenced = false
      next
    end

    s = line[1..].chomp.sub(/\A\s*>\s?/, '')
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
    paragraph << ReviewLoopProse.spans_as_words(s)
  end
rescue SystemCallError => e
  warn e.message
  exit 2
end
check.call
exit(bad ? 1 : 0)
