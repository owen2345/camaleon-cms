=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::PostReorder::AdminController < Apps::PluginsAdminController

  # This updates the position of the elements in the database.
  def reorder_posts
    if params[:values].present?
      params[:values].each_with_index do |value,index |
        post = current_site.posts.find(value)
        taxonomy_id = post.post_type.id
        post.term_relationships.where("term_taxonomy_id = ?", taxonomy_id).first.update_column("term_order", index)
      end
    end

    render inline: "correct"
  end

  # show plugin settings.
  def settings

  end

  # This saves the settings plugin.
  def save_settings
    @plugin = current_site.plugins.find_by_slug("post_reorder")
    @plugin.set_meta("_reorder_objects", params[:object] || {})
    flash[:notice] = "#{t('plugin.post_reorder.updated_changes')}"

    redirect_to admin_plugins_path
  end
end