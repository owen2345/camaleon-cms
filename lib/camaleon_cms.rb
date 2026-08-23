require 'camaleon_cms/engine'
require 'camaleon_cms/version'
require 'camaleon_cms/content_security'
require 'camaleon_cms/unsafe_markup'
require 'camaleon_cms/svg_content_checker'
require 'camaleon_cms/media_security_headers'
require 'camaleon_cms/uploader_content_security'
require 'camaleon_cms/uploader_path_security'
require 'camaleon_cms/uploader_pipeline'
require 'camaleon_cms/uploader_image_processing'
require 'camaleon_cms/uploader_support'
require 'camaleon_cms/captcha_image_generation'
require 'camaleon_cms/task_reporter'
require 'camaleon_cms/shortcode_registry'

module CamaleonCms
end

# Declare core's bundled shortcode names through the boot DSL, then mark the registry available. This
# runs at require time (before any request), so the save-time shortcode gate can detect shortcodes
# with no frontend request. If this ever raises the registry stays unavailable and the gate fails
# closed (non-administrators are refused) rather than fail open on an empty set.
begin
  CamaleonCms::ShortcodeRegistry.register(*CamaleonCms::ShortcodeRegistry::CORE_SHORTCODES)
  CamaleonCms::ShortcodeRegistry.mark_available!
rescue StandardError => e
  warn("CamaleonCms::ShortcodeRegistry boot registration failed (gate fails closed): #{e.message}")
end
