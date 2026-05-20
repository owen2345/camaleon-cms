module CamaleonCms
  module RuntimeStateConcern
    extend ActiveSupport::Concern

    include CamaleonCms::RuntimeShortcodeThemeConcern
    include CamaleonCms::RuntimeHtmlContentConcern
    include CamaleonCms::RuntimeAdminMenuConcern
    include CamaleonCms::RuntimeCaptchaImageConcern
    include CamaleonCms::RuntimeUploaderConcern

    delegate :tag, :content_tag, :safe_join, :image_tag, :link_to, :sanitize, to: :helpers
  end
end
