# frozen_string_literal: true

module CamaleonCms
  # Uploader entry point for views, ActiveJobs, and any standalone object that includes
  # it (see config/initializers/custom_initializers.rb). The implementation lives in the
  # shared modules below, which CamaleonCms::RuntimeUploaderConcern includes as well, so
  # the two entry points cannot drift.
  module UploaderHelper
    include UploaderContentSecurity
    include UploaderPathSecurity
    include UploaderPipeline
    include UploaderImageProcessing
    include UploaderSupport
    include ActionView::Helpers::NumberHelper
    include CamaleonCms::CamaleonHelper

    # Message seam overrides (see CamaleonCms::UploaderPipeline). This entry point runs
    # where `ct` and `cama_t` exist, so upload errors keep going through them: `ct` fires
    # the `on_translation` hook, letting plugins override the text. The pipeline defaults
    # go straight to I18n, which is all a controller can do.
    def cama_uploader_ct(key, args = {})
      ct(key, args)
    end

    def cama_uploader_t(key, args = {})
      cama_t(key, args)
    end

    def cama_uploader_human_size(bytes)
      number_to_human_size(bytes)
    end
  end
end
