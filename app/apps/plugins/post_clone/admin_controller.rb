=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::PostClone::AdminController < Apps::PluginsAdminController
  def clone
    i = [:term_relationships, :metas]
    i << :field_values if @plugin.get_field_value("plugin_clone_custom_fields")
    post = current_site.posts.find(params[:id])
    clone = post.deep_clone(include: i)
    clone.post_type = post.post_type
    slugs = clone.slug.translations
    titles = clone.title.translations
    slugs.each do |k, v|
      slugs[k] = current_site.get_valid_post_slug(v)
      titles[k] = "#{v} (clone)"
    end
    if slugs.empty?
      clone.slug = current_site.get_valid_post_slug(clone.slug)
      clone.title << " (clone)"
    else
      clone.slug = slugs.to_translate
      clone.title = titles.to_translate
    end
    clone.save!
    flash[:notice] = "#{t('plugin.post_clone.message.content_cloned')}"
    redirect_to clone.decorate.the_edit_url
  end

  def settings

  end

  def settings_save
    @plugin.set_field_values(params[:field_options])
    flash[:notice] = "#{t('plugin.post_clone.message.settings_saved')}"
    redirect_to action: :settings
  end
end