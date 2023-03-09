if begin
  CamaleonCms::Site.any?
rescue StandardError
  false
end
  CamaleonCms::Site.all.each do |site|
    site.set_option('refresh_cache', true)
  end
end

module Plugins
  module FrontCache
    module Config
      class Initializer; end
    end
  end
end
