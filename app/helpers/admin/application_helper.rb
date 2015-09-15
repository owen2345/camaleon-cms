=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Admin::ApplicationHelper
  # include Admin::ApiHelper
  include Admin::MenusHelper
  include Admin::PostTypeHelper
  include Admin::CategoryHelper

  # load system notification
  def admin_system_notifications(args)
    if Date.parse(current_site.get_option("date_notified", 2.days.ago).to_s) < Date.today
      current_site.set_option("date_notified", Date.today)
      url = "http://camaleon.tuzitio.com/plugins/camaleon_notification/?version=#{CamaleonCms::VERSION}&admin_locale=#{current_site.get_admin_language}&site=#{current_site.the_url}"
      Thread.new do
        current_site.set_meta("date_notified_message", open(url).read)
        ActiveRecord::Base.connection.close #closing connection
      end
    end
    args[:content] << current_site.get_meta("date_notified_message", "")
  end
end