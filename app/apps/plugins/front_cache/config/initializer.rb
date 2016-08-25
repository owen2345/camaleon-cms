if(CamaleonCms::Site.any? rescue false)
  CamaleonCms::Site.all.each do |site|
    site.set_option("refresh_cache", true)
  end
end
