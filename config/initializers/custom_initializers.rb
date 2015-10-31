=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
# load all custom initializers of plugins or themes
if defined?(PluginRoutes)
  PluginRoutes.all_enabled_apps.each do |ap|
    if ap["path"].present?
      f = File.join(ap["path"], "config", "initializer.rb")
      eval(File.read(f)) if File.exist?(f)
    end
  end
end

require 'base64'
Base64.class_eval do
  def self.un_obfuscate(str)
    Base64.decode64(str.slice(5..-1))
  end
end