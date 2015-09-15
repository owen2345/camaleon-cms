=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
# Rails.application.config.assets.precompile += [/.*\.js/,/.*\.css/]

# Rails.application.config.assets.precompile += Dir[Rails.root.join("app", "apps", "themes", "*", "assets", "**", "^(?!_)*.{js,css,png,jpg,gif}")]
# Rails.application.config.assets.precompile += Dir[Rails.root.join("app", "apps", "plugins", "*", "assets", "**", "^(?!_)*.{js,css,png,jpg,gif}")]
#
# Rails.application.config.assets.precompile += Dir[File.join($camaleon_engine_dir, "app", "apps", "themes", "*", "assets", "**", "^(?!_)*.{js,css,png,jpg,gif}")]
# Rails.application.config.assets.precompile += Dir[File.join($camaleon_engine_dir, "app", "apps", "plugins", "*", "assets", "**", "^(?!_)*.{js,css,png,jpg,gif}")]

# Rails.application.config.assets.precompile += %w( themes/*/assets/css/^(?!_)* )
# Rails.application.config.assets.precompile += %w( plugins/*/assets/js/^(?!_)* )
# Rails.application.config.assets.precompile += %w( themes/*/assets/[images|img]/* )
# Rails.application.config.assets.precompile += %w( plugins/*/assets/[images|img]/* )
# Rails.application.config.assets.precompile += %w( plugins/*/assets/* )

# This will precompile any assets, not just JavaScript (.js, .coffee, .swf, .css, .scss)
Rails.application.config.assets.precompile << /(^[^_\/]|\/[^_])[^\/]*$/