=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::CommonTranslation::AdminController < Apps::PluginsAdminController
  def index
    if params[:custom].present?
      @plugin.set_meta("custom_translations", params[:custom].to_json)
      flash[:notice] = "#{t('plugin.common_translation.message.changes_saved')}"
      redirect_to action: :index
    end
    @common_translations = YAML.load(File.read(Rails.root.join("config", "locales", "common.yml"))).with_indifferent_access
    @custom_translations = @plugin.get_meta("custom_translations")
    @site_languages = current_site.get_languages
  end

end