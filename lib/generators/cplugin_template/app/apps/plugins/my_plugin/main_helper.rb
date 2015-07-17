module Plugins::{plugin_class}::MainHelper

  def self.included(klass)
    #klass.helper_method [:my_helper_method] rescue "" # here your methods accessible from views
  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def {plugin_key}_on_active(plugin)
    # sample: add custom field for this plugin
    group = plugin.add_field_group({name: "Main Settings", slug: "fields", description: ""})
    group.add_field({"name"=>"Setting 1", "slug"=>"setting1"},{field_key: "text_box"})

    # sample: save meta value for this plugin
    plugin.set_meta("installed_at", Time.now.to_s) # save a custom value
  end

  # here all actions on going to inactive
  # plugin: plugin model
  def {plugin_key}_on_inactive(plugin)

  end

  # return array of links for this plugin on plugins list
  def {plugin_key}_options(args)
    args[:links] << link_to("Settings", admin_plugins_{plugin_key}_settings_path)
  end

end