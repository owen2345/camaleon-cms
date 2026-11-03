# frozen_string_literal: true

# The sentence rules that the two prose gates share (docs/ai/prose.md). A sentence has at most LIMIT words, and
# a code span counts as one word. A sentence ends at a period, an exclamation mark or a question mark that a
# space and a word other than a lower-case one follow. CLOSERS are the characters that can follow the end mark.
module ReviewLoopProse
  LIMIT = 25
  CLOSERS = /[*_")\]]/
  BOUNDARY = /(?<=[.!?])#{CLOSERS}*\s+(?=[^a-z\s])|\n\n+/
  CODE_SPAN = /(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)/

  # The String with each code span as one word.
  def self.spans_as_words(text)
    text.gsub(CODE_SPAN, 'X')
  end

  # The sentences of a String whose code spans are words. An empty line ends a sentence too.
  def self.sentences(text)
    text.split(BOUNDARY)
  end

  # The sentences over the limit, each as its word count and the sentence.
  def self.over_limit(sentences)
    sentences.filter_map do |sentence|
      count = sentence.split.size
      [count, sentence] if count > LIMIT
    end
  end

  # The lines that report the sentences over the limit: the word count, the label and the sentence, cut to
  # width characters when given.
  def self.report(sentences, label, width: nil)
    over_limit(sentences).map { |count, sentence| "#{count}#{label}#{width ? sentence[0, width] : sentence}" }
  end

  # True when the sentence ends with an end mark, before any closers.
  def self.ends?(sentence)
    sentence.rstrip.sub(/#{CLOSERS}+\z/, '').end_with?('.', '!', '?')
  end
end
