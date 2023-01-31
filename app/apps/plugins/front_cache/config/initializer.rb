pending_migrations = ActiveRecord::Base.connection.migration_context.needs_migration?
if (CamaleonCms::Site.any? rescue false) && !pending_migrations
  CamaleonCms::Site.all.each do |site|
    site.set_option("refresh_cache", true)
  end
end

class Plugins::FrontCache::Config::Initializer; end
