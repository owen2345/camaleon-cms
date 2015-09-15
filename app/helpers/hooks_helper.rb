=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module HooksHelper
  # execute hooks for plugin_key with action name hook_key
  # non public method
  # plugin: plugin configuration (config.json)
  # hook_key: hook key
  # params: params for hook
  def hook_run(plugin, hook_key, params = nil)
    _do_hook(plugin, hook_key, params)
  end

  # execute all hooks from enabled plugins with key hook_key
  # non public method
  # hook_key: hook key
  # params: params for hook
  def hooks_run(hook_key, params = nil)
    PluginRoutes.enabled_apps(current_site, current_theme.slug).each do |plugin|
      _do_hook(plugin, hook_key, params)
    end
  end

  # skip hook function with name: hook_function_name
  def hook_skip(hook_function_name)
    @_hooks_skip << hook_function_name
  end

  private

  def _do_hook(plugin, hook_key, params =  nil)
    return if !plugin.present? || !plugin["hooks"].present? || !plugin["hooks"][hook_key].present?

    plugin["hooks"][hook_key].each do |hook|
      next if @_hooks_skip.present? && @_hooks_skip.include?(hook)
      begin
        send(hook, params) unless params.nil?
        send(hook) if params.nil?
      rescue
        plugin_load_helpers(plugin)
        send(hook, params) unless params.nil?
        send(hook) if params.nil?
      end
    end
  end
end
