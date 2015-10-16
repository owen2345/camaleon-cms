CamaleonCms::Site.all.each do |site|
  site.set_option("refresh_cache", true)
end