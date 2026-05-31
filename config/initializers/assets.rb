# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

Rails.application.config.tinymce.install = :copy

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
