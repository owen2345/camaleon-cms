# rubocop:disable Style/GlobalVars
module CamaleonCms
  module RuntimeCaptchaImageConcern
    extend ActiveSupport::Concern

    # Kept byte-for-byte in sync with CamaleonCms::CaptchaHelper (both are mixed into the runtime
    # controller stack; see session_captcha_runtime_concern.rb). The length is clamped so an
    # attacker-supplied ?len= can neither exhaust memory by rendering a huge image (H4) nor shrink
    # the answer space to a brute-forceable size (H3).
    CAPTCHA_MIN_LENGTH = 4
    CAPTCHA_MAX_LENGTH = 8
    CAPTCHA_DEFAULT_LENGTH = 5

    def cama_captcha_build(len = 5)
      img = MiniMagick::Image.open(resolve_captcha_file("captcha_#{rand(12)}.jpg"))
      text = cama_rand_str(cama_captcha_length(len))
      # Single active challenge: replace, never accumulate. An append-only list let any previously
      # issued answer keep verifying, which (with a shrinkable length) made the captcha bypassable (H3).
      session[:cama_captcha] = [text]
      img.combine_options do |c|
        c.gravity('Center')
        c.fill('#FFFFFF')
        c.draw("text 0,5 #{text}")
        c.font(resolve_captcha_file('bumpyroad.ttf'))
        c.pointsize('30')
      end
    end

    private

    # Clamp a requested captcha length into the safe range; a non-numeric or absent value
    # falls back to the default. Keep in sync with CamaleonCms::CaptchaHelper#cama_captcha_length.
    def cama_captcha_length(len)
      return CAPTCHA_DEFAULT_LENGTH unless len.to_s.match?(/\A\d+\z/)

      len.to_i.clamp(CAPTCHA_MIN_LENGTH, CAPTCHA_MAX_LENGTH)
    end

    def resolve_captcha_file(filename)
      base_dir = $camaleon_engine_dir.presence || Rails.root.to_s
      File.join(base_dir, 'lib', 'captcha', filename)
    end

    def cama_rand_str(len = 6)
      alphabets = [('A'..'Z').to_a].flatten!
      alphanumerics = [('A'..'Z').to_a, ('1'..'9').to_a].flatten!
      str = alphabets[rand(alphabets.size)]
      (len.to_i - 1).times do
        str << alphanumerics[rand(alphanumerics.size)]
      end
      str
    end
  end
end
# rubocop:enable Style/GlobalVars
