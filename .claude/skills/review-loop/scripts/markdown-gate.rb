#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: <unified diff> | markdown-gate.rb
#
# The Markdown gate of docs/ai/prose.md. It reads a unified diff as UTF-8, on its standard input or from the
# files that it gets as arguments. It prints each added sentence over 25 words. It also prints each paragraph
# that holds an added line, or a removed line between two of its lines, and has more than six sentences. It
# counts the context lines of such a paragraph too. A hunk that starts after line 1 can start inside a fenced
# block, so the gate prints the start line of such a hunk when it holds a fence line: the diff needs more
# context (-U99999). A code span counts as one word. It does not test a table row, a heading or a fenced block.
# It exits with 1 when it printed a line, else with 0, and with 2 for a file that it cannot read.

require_relative 'prose'

LIST_MARK = /\A\s*(?:[-*+]|\d+\.)\s+/
# A fence line: three or more backticks or tildes, then the info string.
FENCE = /\A\s*(`{3,}|~{3,})(.*)/

bad = false
# The added lines since the last line that is not added. Their sentences have the limit of 25 words.
added = []
# The lines of the paragraph in the new text, the context lines included. The paragraph has the limit of six
# sentences when it holds an added line, or a removed line between two of its lines (touched).
paragraph = []
touched = false
# True after a removed line that follows a line of the paragraph. The removed line can join two paragraphs (a
# blank line or a heading), so the next line of the paragraph touches it.
joined = false
# The opening fence of the fenced block that the line is in, else nil.
fence = nil
# The line of the new text where the hunk starts. A hunk that starts after line 1 can start inside a fenced
# block, so a fence in it is refused once (warned).
hunk_start = 1
warned = false

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
  touched = joined = false
  next unless counted

  sentences = ReviewLoopProse.sentences(text)
  next if sentences.size <= 6

  bad = true
  puts "#{sentences.size} sentences: #{text[0, 70]}"
end

# The kind of a line of the diff: :added, :context (an empty line too, which some diff tools write for a blank
# context line), :removed, :marker for a line such as "\ No newline at end of file", or :other for a header. A
# hunk holds the count of old and new lines that its header gives. Only a line outside a hunk is a header, so a
# removed "-- x" (the diff line "--- x") is a removed line, and the header of the next diff ends the hunk.
KINDS = { '+' => :added, ' ' => :context, nil => :context, '-' => :removed }.freeze
old_left = new_left = 0
kind_of = lambda do |line|
  next :marker if line.start_with?('\\')

  if old_left > 0 || new_left > 0
    type = KINDS[line[0]]
    old_left -= 1 unless type == :added
    new_left -= 1 unless type == :removed
    next type if type

    old_left = new_left = 0
  end
  if (counts = line.match(/\A@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@/))
    old_left = (counts[1] || 1).to_i
    new_left = (counts[2] || 1).to_i
  end
  :other
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
    if kind == :removed
      joined = true unless paragraph.empty?
      next
    end

    if kind == :other
      check.call
      fence = nil
      if (start = line[/\A@@ -\d+(?:,\d+)? \+(\d+)/, 1])
        hunk_start = start.to_i
        warned = false
      end
      next
    end

    s = line[1..].to_s.sub(/\A\s*>\s?/, '')
    mark = s.match(FENCE)
    # A backtick fence with a backtick in its info string is a code span, not a fence (CommonMark).
    mark = nil if mark && mark[1].start_with?('`') && mark[2].include?('`')
    if mark && hunk_start > 1 && !warned
      bad = warned = true
      puts "fence in a hunk from line #{hunk_start}: run the diff with -U99999"
    end
    # Only a fence of the same character, at least as long and with no info string, closes the block.
    if fence
      fence = nil if mark && mark[1].start_with?(fence) && mark[2].strip.empty?
      next
    end
    if mark
      check.call
      fence = mark[1]
      next
    end

    if s.strip.empty? || s.match?(/\A\s*(\||#+\s|---)/)
      check.call
      next
    end
    check.call if s.sub!(LIST_MARK, '')
    s = ReviewLoopProse.spans_as_words(s)
    paragraph << s
    touched ||= joined
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
