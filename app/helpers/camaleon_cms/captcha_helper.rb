module CamaleonCms
  module CaptchaHelper
    # Captcha length is clamped to this range so an attacker-supplied ?len= can neither exhaust
    # memory by rendering a huge image (H4) nor shrink the answer space to a brute-forceable size
    # (H3). Kept in sync with CamaleonCms::RuntimeCaptchaImageConcern.
    CAPTCHA_MIN_LENGTH = 4
    CAPTCHA_MAX_LENGTH = 8
    CAPTCHA_DEFAULT_LENGTH = 5

    # build a captcha image
    # @param [Integer, nil] len Number of characters to include in captcha (default: 5)
    # @return [MiniMagick::Image]
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

    def resolve_captcha_file(filename)
      base_dir = $camaleon_engine_dir.presence || Rails.root.to_s
      File.join(base_dir, 'lib', 'captcha', filename)
    end

    # build a captcha tag (image with captcha)
    # img_args: attributes for image_tag
    # input_args: attributes for input field
    def cama_captcha_tag(len = 5, img_args = { alt: '' }, input_args = {}, bootstrap_group_mode = false)
      # Symbolize so string-keyed args work: the :placeholder / :style reads below use Symbol keys,
      # so a caller's String key would be missed — the default placeholder would then be added under
      # the Symbol key and render as a duplicate attribute.
      img_args = img_args.to_h.symbolize_keys
      input_args = input_args.to_h.symbolize_keys
      if input_args[:placeholder].blank?
        input_args[:placeholder] =
          I18n.t('camaleon_cms.captcha_placeholder', default: 'Please enter the text of the image')
      end
      img_args[:onclick] = "this.src = \"#{cama_captcha_url(len: len)}\"+\"&t=\"+(new Date().getTime());"
      # Keep a caller-supplied style; the pointer cursor is required for click-to-refresh, so prepend it.
      img_args[:style] = ['cursor: pointer;', img_args[:style].presence].compact.join(' ')

      helpers = ActionController::Base.helpers
      img = helpers.image_tag(cama_captcha_url(len: len, t: Time.current.to_i), img_args)
      input = helpers.tag(:input, type: 'text', name: 'captcha', **input_args)

      if bootstrap_group_mode
        span = helpers.content_tag(:span, img, class: 'input-group-btn', style: 'vertical-align: top;')
        helpers.content_tag(:div, helpers.safe_join([span, input]), class: 'input-group input-group-captcha')
      else
        helpers.content_tag(:div, helpers.safe_join([img, input]), class: 'input-group-captcha')
      end
    end

    # verify captcha value against the single active challenge and consume it on success, so a solved
    # captcha is single-use and a blank submission can never match (H3).
    def cama_captcha_verified?
      submitted = (params[:cama_captcha] || params[:captcha]).to_s.upcase
      return false if submitted.blank?
      return false unless Array(session[:cama_captcha]).include?(submitted)

      session.delete(:cama_captcha)
      true
    end

    # ************************* captcha in attack helpers ***************************#
    # check if the current visitor was submitted 5+ times
    # key: a string to represent a url or form view
    # key must be the same as the form "captcha_tags_if_under_attack(key, ...)"
    def cama_captcha_under_attack?(key)
      session["cama_captcha_#{key}"] ||= 0
      session["cama_captcha_#{key}"].to_i > current_site.get_option('max_try_attack', 5).to_i
    end

    # verify captcha values if this key is under attack
    # key: a string to represent a url or form view
    def captcha_verify_if_under_attack(key)
      # Verify once: cama_captcha_verified? consumes the challenge, so a second call would
      # always be false and would never reset the attack counter after a genuine solve.
      verified = cama_captcha_verified?
      res = cama_captcha_under_attack?(key) ? verified : true
      session["cama_captcha_#{key}"] = 0 if verified
      res
    end

    # increment attempts for key by 1
    def cama_captcha_increment_attack(key)
      session["cama_captcha_#{key}"] ||= 0
      session["cama_captcha_#{key}"] = session["cama_captcha_#{key}"].to_i + 1
    end

    # reset the attacks counter for key
    # key: a string to represent a url or form view
    def cama_captcha_reset_attack(key)
      session["cama_captcha_#{key}"] = 0
    end

    # return a number of attempts for key
    # key: a string to represent a url or form view
    def cama_captcha_total_attacks(key)
      session["cama_captcha_#{key}"] ||= 0
    end

    # show captcha if under attack
    # key: a string to represent a url or form view
    def cama_captcha_tags_if_under_attack(key, captcha_parmas = [5, {}, { class: 'form-control required' }])
      cama_captcha_tag(*captcha_parmas) if cama_captcha_under_attack?(key)
    end

    private

    # Clamp a requested captcha length into the safe range; a non-numeric or absent value
    # falls back to the default. Keep in sync with CamaleonCms::RuntimeCaptchaImageConcern.
    def cama_captcha_length(len)
      return CAPTCHA_DEFAULT_LENGTH unless len.to_s.match?(/\A\d+\z/)

      len.to_i.clamp(CAPTCHA_MIN_LENGTH, CAPTCHA_MAX_LENGTH)
    end

    # generate random string for captcha
    # len: length of characters, default 6
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
