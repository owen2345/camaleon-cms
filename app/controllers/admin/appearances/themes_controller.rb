=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::Appearances::ThemesController < Admin::AppearancesController
  # list themes or update a theme status
  def index
    PluginRoutes.reload
    authorize! :manager, :themes
    if params[:set].present?
      site_install_theme(params[:set])
      flash.now[:notice] = t('admin.themes.message.updated')
      redirect_to action: :index
    end
  end

  def load_data
    file = Rails.root.join("app", "apps", 'themes', current_site.get_theme_slug, 'data.json')
    @messages = load_file_content_to_db(file, {post_types: 1, clear_post_type: 1, nav_menus: 1, clear_nav_menus: 1, slider_basic: 1, clear_slider_basic: 1, theme_import: 1})
  end

  def preview
    render layout: false
  end
end
