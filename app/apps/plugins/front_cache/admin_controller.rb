=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::FrontCache::AdminController < Apps::PluginsAdminController
  include Plugins::FrontCache::FrontCacheHelper
  def settings
    add_asset_library("multiselect")
    @caches = current_site.get_meta("front_cache_elements", {})
    @caches[:paths] << "" unless @caches[:paths].present?
  end

  def save_settings
    current_site.set_meta("front_cache_elements", {paths: (params[:cache][:paths].delete_if{|a| !a.present?  } ||[]),
                                                   posts: (params[:cache][:posts]||[]),
                                                   post_types: (params[:cache][:post_type]||[]),
                                                   skip_posts: (params[:cache][:skip_posts]||[]),
                                                   cache_login: params[:cache][:cache_login],
                                                   home: params[:cache][:home]
                                                  })
    flash[:notice] = "#{t('plugin.front_cache.message.settings_saved')}"
    redirect_to action: :settings
  end

  def clean_cache
    flash[:notice] = "#{t('plugin.front_cache.message.cache_destroyed')}"
    front_cache_clean()
    redirect_to :back
  end

end