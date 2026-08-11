module CamaleonCms
  module CaptchaHelper
    # Challenge/image generation (including the length clamp and its constants) lives in
    # CamaleonCms::CaptchaImageGeneration, shared with the controller-stack
    # CamaleonCms::RuntimeCaptchaImageConcern; verification and the under-attack counters
    # below exist only here.
    include CamaleonCms::CaptchaImageGeneration

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

    # verify the captcha only when this key is under attack; reports solely whether the
    # current challenge was solved. The attack counter is cleared only by an explicit
    # cama_captcha_reset_attack once the protected action itself succeeds (as the login
    # flows do), so solving a captcha can no longer buy captcha-free attempts for an
    # otherwise failing action. When the key is not under attack, the pending challenge
    # is left unconsumed for whatever form it belongs to.
    def captcha_verify_if_under_attack(key)
      return true unless cama_captcha_under_attack?(key)

      cama_captcha_verified?
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
  end
end
