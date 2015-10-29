=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::ContactForm::FrontController < CamaleonCms::Apps::PluginsFrontController
  before_filter :append_view_paths

  def index
    # here your actions for frontend module
  end

  # here add your custom functions
  def save_form
    @form = current_site.contact_forms.find_by_id(params[:id])
    values = JSON.parse(@form.value).to_sym
    settings = JSON.parse(@form.settings).to_sym
    fields = params[:fields]
    errors = []
    success = []

    perform_save_form(@form, values, fields, settings, success, errors)
    if success.present?
      flash[:notice] = success.join('<br>')
    else
      flash[:error] = errors.join('<br>')
      flash[:values] = fields
    end

    redirect_to :back
  end

  private

  def append_view_paths
    append_view_path File.join($camaleon_engine_dir, 'app', 'apps', 'plugins', self_plugin_key, 'views')
  end

  def fix_meta_value(value)
    if value.is_a?(Array) || value.is_a?(Hash)
      value = value.to_json
    elsif value.is_a?(String)
      value = value.to_var
    end
    value
  end
end