# class Plugins::{plugin_class}::Models::{plugin_class} < ActiveRecord::Base
  # attr_accessible :path, :browser_key
  # belongs_to :site

  # here create your models normally
  # notice: your tables in database will be plugins_{plugin_key} in plural (check rails documentation)
# end

# here your default models customization
# Site.class_eval do
#   has_many :{plugin_key}, class_name: "Plugins::{plugin_class}::Models::{plugin_class}"
# end