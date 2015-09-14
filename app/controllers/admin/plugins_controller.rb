=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::PluginsController < AdminController
  before_action :validate_role
  def index
    PluginRoutes.reload
  end

  def toggle
    status = params[:status].to_bool
    if status == true # to inactivate
      plugin = plugin_uninstall(params[:id])
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_inactivated')}"
    end

    unless status # to activate
      plugin = plugin_install(params[:id])
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_activated')}"
    end
    PluginRoutes.reload
    redirect_to action: :index
  end

  # permit to upgrade a plugin for a new version
  def upgrade
    plugin = plugin_upgrade(params[:plugin_id])
    flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_upgraded')}"
    PluginRoutes.reload
    redirect_to action: :index
  end

  def destroy
    plugin = plugin_destroy(params[:id])
    if plugin.error
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_removed')}"
    else
      flash[:error] = "Plugin \"#{plugin.title}\" #{t('admin.message.can_not_be_removed')}"
    end
    redirect_to action: :index
  end

  private

  def validate_role
    authorize! :manager, :plugins
  end
end
