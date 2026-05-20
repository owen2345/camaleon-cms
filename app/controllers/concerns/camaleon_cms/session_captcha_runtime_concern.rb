module CamaleonCms
  module SessionCaptchaRuntimeConcern
    extend ActiveSupport::Concern

    def captcha_verify_if_under_attack(key)
      cama_captcha_under_attack?(key) ? cama_captcha_verified? : true
    end

    def cama_captcha_under_attack?(key)
      session["cama_captcha_#{key}"] ||= 0
      session["cama_captcha_#{key}"].to_i > current_site.get_option('max_try_attack', 5).to_i
    end

    def cama_captcha_verified?
      (session[:cama_captcha] || []).include?((params[:cama_captcha] || params[:captcha]).to_s.upcase)
    end

    def cama_captcha_increment_attack(key)
      session["cama_captcha_#{key}"] ||= 0
      session["cama_captcha_#{key}"] = session["cama_captcha_#{key}"].to_i + 1
    end

    def cama_captcha_reset_attack(key)
      session["cama_captcha_#{key}"] = 0
    end

    def cama_captcha_total_attacks(key)
      session["cama_captcha_#{key}"] ||= 0
    end

    def cama_captcha_tags_if_under_attack(key, captcha_parmas = [5, {}, { class: 'form-control required' }])
      cama_captcha_tag(*captcha_parmas) if cama_captcha_under_attack?(key)
    end
  end
end
