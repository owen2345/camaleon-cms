=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::PostReorder::PostReorderHelper

  # get the plugin name with slug: 'post_reorder'
  def get_plugin
    plugin = current_site.plugins.find_by_slug("post_reorder")
  end

  def post_reorder_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def post_reorder_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def post_reorder_on_inactive(plugin)

  end

  # This adds a javascript to rearrange the elements of any type of content
  def post_reorder_on_list_post(values)

    plugin_meta = get_plugin.get_meta('_reorder_objects')

    if plugin_meta.present?
      plugin_meta[:post_type].each do |meta|
        if meta.to_i == values[:post_type].id.to_i
          append_asset_libraries({reorder: {js: [plugin_asset_path("post_reorder", "js/reorder.js")], css: [plugin_asset_path("post_reorder", "css/reorder.css")]}})
          content_append('<script>
                      run.push(function(){
                        $.fn.reorder({url: "'+admin_plugins_post_reorder_reorder_posts_path+'", table: "#posts-table-list"});
                      });
                    </script>')
        end
      end
    end
  end

  # This will add link options for this plugin.
  def post_reorder_plugin_options(arg)
    arg[:links] << link_to(t('plugin.post_reorder.settings'), admin_plugins_post_reorder_settings_path)
  end

end