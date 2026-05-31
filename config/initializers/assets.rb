# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.1'

Rails.application.config.tinymce.install = :copy

# TinyMCE editor icons in development.
#
# sprockets-rails >= 3.5 registers `Sprockets::Rails::AssetUrlProcessor`, a `text/css`
# post-processor that rewrites every relative `url(...)` reference to a digested asset
# path. TinyMCE's bundled skin (`tinymce/skins/lightgray/skin.min.css`) references its
# icon font with directory-relative urls such as `url('fonts/tinymce.woff')`. Sprockets
# resolves `url()` paths against the asset load roots (not the referencing file's own
# directory), so it cannot find `fonts/tinymce.woff` (its real logical path is
# `tinymce/skins/lightgray/fonts/...`) and rewrites it to an invalid root path
# (`/fonts/tinymce.woff`) which 404s, leaving the editor toolbar without icons.
#
# In production this never happens: `tinymce.install = :copy` ships the skin as raw static
# files under `public/assets`, bypassing Sprockets (and this processor) entirely. The bug
# only surfaces in environments that compile assets on the fly (development).
#
# We must NOT disable the processor globally: other stylesheets (e.g. Bootstrap, whose
# glyphicon @font-face urls are relative) rely on it to produce resolvable digested paths.
# Instead, swap it for a thin subclass that, for the TinyMCE skin only, first expands the
# skin's directory-relative font urls into full logical asset paths (prefixing them with the
# skin's own logical directory) before delegating to the original processor. The original
# then resolves and digests them correctly. Every other stylesheet is processed unchanged.
if defined?(Sprockets::Rails::AssetUrlProcessor) && Rails.application.config.assets.compile &&
   Sprockets.respond_to?(:unregister_postprocessor) && Sprockets.respond_to?(:register_postprocessor)
  class TinymceSkinSafeAssetUrlProcessor < Sprockets::Rails::AssetUrlProcessor
    SKIN_MARKER = 'tinymce/skins/'.freeze
    # Directory-relative `url(...)` references that are not absolute/external/data urls.
    RELATIVE_URL = %r{url\(\s*["']?(?!(?:#|data|http|/))(?:\./)?(?<path>[^"'\s)]+)\s*["']?\)}

    def self.call(input)
      filename = input[:filename].to_s
      return super unless filename.include?(SKIN_MARKER)

      logical_dir = File.dirname(filename[filename.index('tinymce/')..])
      rewritten = input[:data].gsub(RELATIVE_URL) do
        "url(#{logical_dir}/#{Regexp.last_match(:path)})"
      end
      super(input.merge(data: rewritten))
    end
  end

  Sprockets.unregister_postprocessor('text/css', Sprockets::Rails::AssetUrlProcessor)
  Sprockets.register_postprocessor('text/css', TinymceSkinSafeAssetUrlProcessor)
end

# Add additional assets to the asset load path
Rails.application.config.assets.precompile += %w[camaleon_cms/*]
# Rails.application.config.assets.precompile += %w( themes/*/assets/* )

# Precompile plugin/theme assets that live under app/apps/{plugins,themes}/.../assets.
# Rails' default precompile rules only cover app/assets, so without this plugin/theme
# assets are never declared as precompiled and `javascript_include_tag` /
# `stylesheet_link_tag` raise `AssetNotPrecompiledError` on Sprockets >= 4 when
# `unknown_asset_fallback` is disabled. Sprockets 4 only resolves exact logical paths
# (globs/procs are not honored by `asset_precompiled?`), so we enumerate them as strings.
require 'camaleon_cms/assets_precompile'
Rails.application.config.assets.precompile += CamaleonCms::AssetsPrecompile.logical_paths
