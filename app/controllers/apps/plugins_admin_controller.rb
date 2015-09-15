=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Apps::PluginsAdminController < AdminController
  before_action :init_plugin

  private

  def init_plugin
    plugin_name = params[:controller].split("/")[1]
    @plugin = current_site.plugins.where(slug: plugin_name).first
    return render_error(404) unless @plugin.active?
    lookup_context.prefixes.prepend(params[:controller].sub("plugins/#{plugin_name}", "#{plugin_name}/views"))
  end
end
