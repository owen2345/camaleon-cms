# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
Rails.application.config.assets.precompile += [/.*\.js/,/.*\.css/]

Rails.application.config.assets.precompile += Dir[Rails.root.join("app", "apps", "themes", "*", "assets", "**", "*.{js,css,png,jpg,gif}")]
Rails.application.config.assets.precompile += Dir[Rails.root.join("app", "apps", "plugins", "*", "assets", "**", "*.{js,css,png,jpg,gif}")]

Rails.application.config.assets.precompile += Dir[File.join($camaleon_engine_dir, "app", "apps", "themes", "*", "assets", "**", "*.{js,css,png,jpg,gif}")]
Rails.application.config.assets.precompile += Dir[File.join($camaleon_engine_dir, "app", "apps", "plugins", "*", "assets", "**", "*.{js,css,png,jpg,gif}")]

Rails.application.config.assets.precompile += %w( themes/*/assets/images/* )
Rails.application.config.assets.precompile += %w( plugins/*/assets/images/* )