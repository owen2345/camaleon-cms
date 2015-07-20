module Plugins::{plugin_class}::MainHelper

  def self.included(klass)
    #klass.helper_method [:my_helper_method] rescue "" # here your methods accessible from views
  end

  # here all actions on plugin destroying
  # plugin: plugin model
  def {plugin_key}_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def {plugin_key}_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def {plugin_key}_on_inactive(plugin)

  end

end