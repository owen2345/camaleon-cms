require 'rufus-scheduler'
$scheduler = Rufus::Scheduler.new

$scheduler.cron '00 05 * * *' do
  system("rake sitemap:generate")
end

#cronjob for hook by site
begin
  Site.all.each do |site|
    # hooks
    c = ApplicationController.new
    c.instance_eval do
      @current_site = site
      @_hooks_skip = []
    end
    r = {site: site, eval: ""}; c.hooks_run("cron", r)
    instance_eval(r[:eval]) if r[:eval].present?
  end
rescue => e # skipping sites not found

end



####### DELAYED JOBS

# auto delete file after a time
class TemporalFileJob < ActiveJob::Base
  queue_as "destroy_temporal_file"
  def perform(file_path)
    FileUtils.rm_rf(file_path) if File.exist?(file_path) && !File.directory?(file_path)
  end
end