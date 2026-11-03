#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: message-gate.rb <file>
#
# The message gate of the review loop (procedure.md, Ledger rows). The file holds a commit message: a subject
# line and at most three sentences, each of at most 25 words. A code span counts as one word. The gate prints
# each sentence over 25 words, and the count of the sentences after the subject when it is over three. It exits
# with 1 when it printed a line, else with 0. It exits with 2 without a file argument, or for a file that it
# cannot read.

require_relative 'prose'

unless ARGV.size == 1
  warn 'Usage: message-gate.rb <file>'
  exit 2
end

begin
  text = File.read(ARGV[0], encoding: 'UTF-8')
rescue SystemCallError => e
  warn e.message
  exit 2
end
text = ReviewLoopProse.spans_as_words(text.scrub)
sentences = ReviewLoopProse.sentences(text)
lines = ReviewLoopProse.report(sentences, ': ')
puts lines
bad = lines.any?
count = sentences.drop(1).count { |sentence| ReviewLoopProse.ends?(sentence) }
if count > 3
  bad = true
  puts "#{count} sentences"
end
exit(bad ? 1 : 0)
