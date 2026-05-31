module CamaleonCms
  # Wires the captcha helper into the runtime controller stack. All behaviour
  # (image/tag building, verification and the under-attack session counters)
  # lives in CamaleonCms::CaptchaHelper (single source of truth shared with
  # views), so the controller and view contexts cannot drift apart.
  #
  # CaptchaHelper is ivar-free (it only touches session/params/current_site and
  # ActionController::Base.helpers), so it is safe to mix into the controller.
  # Including it here restores `cama_captcha_tag`/`cama_captcha_build` on the
  # controller runtime stack so shortcodes/forms rendered in controller context
  # (e.g. the contact-form plugin) can call them.
  module SessionCaptchaRuntimeConcern
    extend ActiveSupport::Concern

    include CamaleonCms::CaptchaHelper
  end
end
