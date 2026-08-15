# frozen_string_literal: true

require 'rails_helper'

# Security (audit Low): the captcha challenge string was built with Kernel#rand, a Mersenne-Twister
# PRNG whose future output is predictable from observed samples — so an attacker who has seen a few
# challenges could anticipate the next. The challenge now draws from SecureRandom (a CSPRNG).
RSpec.describe CamaleonCms::CaptchaImageGeneration, '#cama_rand_str' do
  let(:generator) { Class.new { include CamaleonCms::CaptchaImageGeneration }.new }

  it 'draws its characters from a CSPRNG, not Kernel#rand' do
    expect(SecureRandom).to receive(:random_number).at_least(:once).and_call_original

    generator.send(:cama_rand_str, 6)
  end

  it 'still produces a string of the requested length from the captcha alphabet' do
    str = generator.send(:cama_rand_str, 6)

    expect(str.length).to eq(6)
    expect(str).to match(/\A[A-Z][A-Z1-9]{5}\z/)
  end
end
