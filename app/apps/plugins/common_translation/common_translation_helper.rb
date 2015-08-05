=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::CommonTranslation::CommonTranslationHelper


  # here all actions on plugin destroying
  # plugin: plugin model
  def common_translation_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def common_translation_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def common_translation_on_inactive(plugin)

  end

  def common_translation_on_translation(args)
    begin
      @_plugin_custom_translation_vals ||= current_site.plugins.where(slug: "common_translation").first.get_meta("custom_translations")
      c_trans = @_plugin_custom_translation_vals[args[:locale]][args[:key].to_sym]
      if c_trans
        args[:translation] = c_trans
        args[:flag] = true
      end
    rescue Exception => e
    end
  end

  def common_translation_plugin_options(arg)
    arg[:links] << link_to(t('plugin.common_translation.settings'), admin_plugins_common_translation_index_path)
  end
end