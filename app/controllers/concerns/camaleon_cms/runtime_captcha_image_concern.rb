module CamaleonCms
  # Controller-stack entry point for captcha image generation: GET /captcha
  # (CamaleonController#captcha) resolves cama_captcha_build through this concern.
  # The implementation lives in CamaleonCms::CaptchaImageGeneration, shared with
  # CamaleonCms::CaptchaHelper, so a captcha hardening fix cannot land in one entry
  # point and not the other (parity is guarded by
  # spec/lib/camaleon_cms/captcha_implementation_parity_spec.rb).
  module RuntimeCaptchaImageConcern
    extend ActiveSupport::Concern

    include CamaleonCms::CaptchaImageGeneration
  end
end
