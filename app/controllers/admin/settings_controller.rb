=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::SettingsController < AdminController
  before_action :validate_role

  def index
    redirect_to admin_dashboard_path
  end

  def site
    @site = current_site
  end

  def site_saved
    @site = current_site
    if @site.update(params[:site])
      @site.set_options_from_form(params[:meta]) if params[:meta].present?
      @site.set_multiple_options(params[:options])
      @site.set_field_values(params[:field_options])
      theme = @site.get_theme.decorate
      theme.set_field_values(params[:theme_fields]) if params[:theme_fields].present?
      flash[:notice] = t('admin.settings.message.site_updated')
      hook_run(theme.settings, "on_theme_settings", theme)
      redirect_to action: :site
    else
      render 'site'
    end
  end

  # list available languages
  def languages
  end

  # save language customizations
  def save_languages
    current_site.set_meta("languages_site", params[:lang])
    current_site.set_admin_language(params[:admin_language])
    I18n.locale = current_site.get_admin_language
    PluginRoutes.reload

    flash[:notice] =  t('admin.settings.message.language_updated', locale: current_site.get_admin_language)
    redirect_to action: :languages
  end

  private

  def validate_role
    authorize! :manager, :settings
  end
end
