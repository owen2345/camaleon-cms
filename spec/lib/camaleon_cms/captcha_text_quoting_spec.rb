# frozen_string_literal: true

# ImageMagick reads an unquoted NAN or INF at the start of the text of a draw primitive as a
# number, so a challenge such as NANGR broke the text primitive and the captcha request raised.
# The text is now quoted. Needs ImageMagick (CI installs it).
RSpec.describe CamaleonCms::CaptchaImageGeneration, '#cama_captcha_build' do
  let(:generator) do
    Class.new do
      include CamaleonCms::CaptchaImageGeneration

      attr_accessor :session

      def initialize
        @session = {}
      end
    end.new
  end

  before do
    # MiniMagick runs `magick mogrify` when the ImageMagick 7 `magick` binary exists.
    skip 'ImageMagick is not installed' unless %w[magick mogrify].any? { |bin| MiniMagick::Utilities.which(bin) }
  end

  %w[NANGR INF2B].each do |text|
    it "draws a challenge that starts with #{text[0, 3]}" do
      allow(generator).to receive(:cama_rand_str).and_return(text)

      image = generator.cama_captcha_build

      expect(image).to be_a(MiniMagick::Image)
      expect(generator.session[:cama_captcha]).to eq([text])
    end
  end
end
