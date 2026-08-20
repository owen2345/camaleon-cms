module CamaleonCms
  # Wires the captcha helper into the runtime controller stack. Tag building,
  # verification and the under-attack session counters live only in
  # CamaleonCms::CaptchaHelper (shared with views); challenge/image generation
  # lives in CamaleonCms::CaptchaImageGeneration, which both the helper and the
  # controller-stack RuntimeCaptchaImageConcern include (parity-guarded), so the
  # controller and view contexts cannot drift apart.
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
