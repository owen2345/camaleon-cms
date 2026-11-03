# frozen_string_literal: true

# The sentence rules that both prose gates follow (scripts/prose.rb). The group that includes them defines
# `gate(text, env:)` and `gate_text(sentence)`, which wraps one sentence into an input of the gate. `prefix` is
# what a printed line holds between the word count and the sentence.
RSpec.shared_examples 'a prose gate' do |prefix|
  it 'passes a sentence of 25 words' do
    result = gate(gate_text("#{words(25)}."))
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end

  it 'prints a sentence of 26 words and exits with 1' do
    result = gate(gate_text("#{words(26)}."))
    expect(result.out).to start_with("26#{prefix}#{"#{words(26)}."[0, 70]}")
    expect(result.status).to eq(1)
  end

  it 'counts a code span as one word' do
    result = gate(gate_text("#{words(24)} `one two three four five`."))
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end

  it 'counts each code span of a sentence as one word' do
    result = gate(gate_text("`one` #{words(24)} `two`."))
    expect(result.out).to start_with("26#{prefix}")
    expect(result.status).to eq(1)
  end

  it 'splits a sentence that ends in two stars from the next one' do
    result = gate(gate_text("**#{words(20)}.** #{words(20)}."))
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end

  it 'ends a sentence at a question mark and at an exclamation mark' do
    result = gate(gate_text("#{words(20)}? #{words(20)}! #{words(20)}."))
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end

  it 'reads a sentence that holds an invalid UTF-8 byte' do
    result = gate(gate_text("bad \xFF byte here."))
    expect(result.out).to eq('')
    expect(result.status).to eq(0)
  end
end
