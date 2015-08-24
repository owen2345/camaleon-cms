# desc "Explaining what the task does"
# task :camaleon_cms do
#   # Task goes here
# end

namespace :camaleon_cms do
  task :sitemap => :environment do
    include Rails.application.routes.url_helpers
    include Frontend::ApplicationHelper
    include SiteHelper
    include PluginsHelper
    include HooksHelper

    start_time = Time.now
    DynamicSitemaps::Logger.info "Generating sitemap..."
    DynamicSitemaps.generate_sitemap
    DynamicSitemaps::Logger.info "Done generating sitemap in #{Time.now - start_time} seconds."
  end
end