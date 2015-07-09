require File.expand_path('../boot', __FILE__)

require 'rails/all'
require './lib/ext/string'
require './lib/ext/hash'
require './lib/ext/array'
require './lib/ext/translator'
require './lib/plugin_routes'
require './lib/aes_crypt'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module WPRails
  class Application < Rails::Application
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = PluginRoutes.system_info[:locale]
    config.time_zone = PluginRoutes.system_info[:time_zone]

    config.assets.paths << Rails.root.join("app", "apps")
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
    config.encoding = "utf-8"

    #multiple route files
    config.paths["config/routes.rb"].concat(Dir[Rails.root.join("config/routes/*.rb")])

    # extra configuration for plugins
    config.autoload_paths << Rails.root.join('app','apps','**/')
    PluginRoutes.all_plugins.each do |plugin|
      config.paths["db/migrate"] << File.join(plugin["path"], "migrate") if Dir.exist?(File.join(plugin["path"], "migrate"))
    end

    PluginRoutes.all_apps.each do |info|
      config.i18n.load_path += Dir[File.join(info["path"], "config", "locales", '*.{rb,yml}')]
    end
    # end extra configuration for plugins

    config.cache_store = :file_store, Rails.root.join("tmp","cache","vars")
    config.action_controller.page_cache_directory = Rails.root.join("tmp","cache","pages")
  end
end
