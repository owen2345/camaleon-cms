=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
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
if defined?(ActiveJob::Base)
  class TemporalFileJob < ActiveJob::Base
    queue_as "destroy_temporal_file"
    def perform(file_path)
      FileUtils.rm_rf(file_path) if File.exist?(file_path) && !File.directory?(file_path)
    end
  end
end