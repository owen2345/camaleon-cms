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

Rails.application.config.tinymce.install = :compile

# Add additional assets to the asset load path
Rails.application.config.assets.precompile += %w( camaleon_cms/* )
Rails.application.config.assets.precompile += %w( themes/*/assets/* )

# This will precompile any assets, not just JavaScript (.js, .coffee, .swf, .css, .scss)
Rails.application.config.assets.precompile << Proc.new { |path|
  name = File.basename(path)
  content_type = MIME::Types.type_for(name).first.content_type rescue ""
  res = false
  if (path =~ /\.(css|js|svg|ttf|woff|eot|swf|pdf)\z/ || content_type.scan(/(javascript|image\/|audio|video|font)/).any?) && !name.start_with?("_") && !path.include?('/views/')
    res = true
  end
  res
}
