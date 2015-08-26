# class Plugins::PluginClass::Models::PluginClass < ActiveRecord::Base
  # attr_accessible :path, :browser_key
  # belongs_to :site

  # here create your models normally
  # notice: your tables in database will be plugins_pluginKey in plural (check rails documentation)
# end

# here your default models customization
# Site.class_eval do
#   has_many :pluginKey, class_name: "Plugins::PluginClass::Models::PluginClass"
# end