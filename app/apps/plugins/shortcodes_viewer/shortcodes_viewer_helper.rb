=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::ShortcodesViewer::ShortcodesViewerHelper

  # here all actions before admin load
  def shortcodes_viewer_admin_before_load
    #admin_menu_append_menu_item("settings", {icon: "code", title: "Shortcodes", url: admin_plugins_shortcodes_viewer_index_path})
  end

  def shortcodes_viewer_plugin_options(arg)
    arg[:links] << link_to(t('plugin.shortcodes_viewer.settings'), admin_plugins_shortcodes_viewer_settings_path)
  end
end