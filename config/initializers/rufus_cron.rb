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
  loaded_rufus = true
rescue LoadError
  loaded_rufus = false
end

if loaded_rufus
  $scheduler = Rufus::Scheduler.singleton
  $scheduler.cron '00 05 * * *' do
    system("rake camaleon_cms:sitemap")
  end

  sites = Site.all rescue []
  sites.each do |site|
    # triggering cron hooks
    c = CamaleonController.new
    c.instance_eval do
      @current_site = site
      @_hooks_skip = []
    end
    r = {site: site, eval: nil}; c.hooks_run("cron", r)
    r[:eval].call(r) if r[:eval].present? # evaluate the cron job created by plugin or theme
  end
end