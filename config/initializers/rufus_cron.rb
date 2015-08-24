begin
  require 'rufus-scheduler'
  $scheduler = Rufus::Scheduler.singleton
  $scheduler.cron '00 05 * * *' do
    system("rake camaleon_cms:sitemap")
  end
  #cronjob for hook by site
  begin
    Site.all.each do |site|
      # hooks
      c = CamaleonController.new
      c.instance_eval do
        @current_site = site
        @_hooks_skip = []
      end
      r = {site: site, eval: nil}; c.hooks_run("cron", r)
      r[:eval].call(r) if r[:eval].present?
    end
  rescue => e # skipping sites not found

  end
rescue LoadError
  
end

# only for camaleon site
# $scheduler.cron '00 04 * * *' do
#   include SiteHelper
#   include PluginsHelper
#   include HooksHelper
#   Site.where(slug: "demo").destroy_all
#   site = Site.create(name: "Demo", slug: "demo")
#   @current_site = site
#   site_after_install(site)
# end

####### DELAYED JOBS
# auto delete file after a time
class TemporalFileJob < ActiveJob::Base
  queue_as "destroy_temporal_file"
  def perform(file_path)
    FileUtils.rm_rf(file_path) if File.exist?(file_path) && !File.directory?(file_path)
  end
end