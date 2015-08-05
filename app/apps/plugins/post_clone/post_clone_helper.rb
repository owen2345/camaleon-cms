=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::PostClone::PostCloneHelper

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def post_clone_on_active(plugin)
    options = [{"title"=>"Enable?", "value"=>"1", "default"=>"1"}]
    group = plugin.add_custom_field_group({name: "#{t('plugin.post_clone.post_clone_configuration')}", slug: "plugin_clone_custom_settings", description: ""})
    group.add_manual_field({"name"=>"#{t('plugin.post_clone.clone_custom_fields')}", "slug"=>"plugin_clone_custom_fields", "description"=>"#{t('plugin.post_clone.clone_custom_field_values')}"},
                           {field_key: "checkboxes", multiple: false, required: false, multiple_options: options})
    group.add_manual_field({"name"=>"#{t('plugin.post_clone.saved_pending')}", "slug"=>"plugin_clone_save_as_pending", "description"=>"#{t('plugin.post_clone.want_save_pending')}"},
                           {field_key: "checkboxes", multiple: false, required: false, multiple_options: [{"title"=>"#{t('plugin.post_clone.enable')}", "value"=>"1", "default"=>"0"}]})
  end

  # here all actions on going to inactive
  # plugin: plugin model
  def post_clone_on_inactive(plugin)
    plugin.get_field_groups().destroy_all
  end

  def post_clone_new_post(args)

  end

  def post_clone_edit_post(args)
    args[:extra_settings] <<
        "<div class=''><label class='control-label'>#{t('admin.post.clone_content')}: </label> <a href='#{admin_plugins_post_clone_clone_path(id: args[:post].id)}'><i class='fa fa-copy'></i> #{t('admin.post.clone')}</a> </div>"
  end

  def post_clone_plugin_options(arg)
      arg[:links] << link_to(t('plugin.post_clone.settings'), admin_plugins_post_clone_settings_path)
  end

end