module CamaleonCms
  module CaptchaHelper
    # build a captcha image
    # @param [Integer, nil] len Number of characters to include in captcha (default: 5)
    # @return [MiniMagick::Image]
    def cama_captcha_build(len = 5)
      img = MiniMagick::Image.open(resolve_captcha_file("captcha_#{rand(12)}.jpg"))
      text = cama_rand_str(len)
      session[:cama_captcha] = [] if session[:cama_captcha].blank?
      session[:cama_captcha] << text
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
      if input_args[:placeholder].blank?
        input_args[:placeholder] =
          I18n.t('camaleon_cms.captcha_placeholder', default: 'Please enter the text of the image')
      end
      img_args[:onclick] = "this.src = \"#{cama_captcha_url(len: len)}\"+\"&t=\"+(new Date().getTime());"
      img_args[:style] = 'cursor: pointer;'

      helpers = ActionController::Base.helpers
      img = helpers.image_tag(cama_captcha_url(len: len, t: Time.current.to_i), img_args)
      input = helpers.tag(:input, type: 'text', name: 'captcha', **input_args)

      if bootstrap_group_mode
        span = helpers.content_tag(:div, img, class: 'input-group-append', style: 'vertical-align: top;')
        helpers.content_tag(:div, helpers.safe_join([span, input]), class: 'input-group input-group-captcha')
      else
        helpers.content_tag(:div, helpers.safe_join([img, input]), class: 'input-group-captcha')
      end
    end

    # verify captcha value
    def cama_captcha_verified?
      (session[:cama_captcha] || []).include?((params[:cama_captcha] || params[:captcha]).to_s.upcase)
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
      res = cama_captcha_under_attack?(key) ? cama_captcha_verified? : true
      session["cama_captcha_#{key}"] = 0 if cama_captcha_verified?
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
