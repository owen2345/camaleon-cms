require 'rubygems'
require 'actionpack/page_caching'
require 'bcrypt'
require 'cancancan'
require 'draper'
require 'dynamic_sitemaps'
require 'el_finder'
require 'meta-tags'
require 'mini_magick'
require 'mobu'
require 'protected_attributes'
require 'rufus-scheduler'
require 'will_paginate'
require 'will_paginate-bootstrap'
require 'doorkeeper'
require 'responders'
require 'swagger/docs'
require 'active_model_serializers'

$camaleon_engine_dir = File.expand_path("../../../", __FILE__)
require File.join($camaleon_engine_dir, "lib", "plugin_routes").to_s
Dir[File.join($camaleon_engine_dir, "lib", "ext", "**", "*.rb")].each{ |f| require f }
module CamaleonCms
  class Engine < ::Rails::Engine
    config.before_initialize do |app|
      if app.respond_to?(:console)
        app.console do
          puts "******** Camaleon CMS: To use custom models and helpers of installed plugins, write this: ********"
          puts "- include SiteHelper"
          puts "- site_console_switch(Site.first.decorate)"
        end
      end
    end

    initializer :append_migrations do |app|
      engine_dir = File.expand_path("../../../", __FILE__)
      app.config.i18n.load_path += Dir[File.join($camaleon_engine_dir, 'config', 'locales', '**', '*.{rb,yml}')]
      app.config.i18n.enforce_available_locales = false
      PluginRoutes.all_apps.each{ |info| app.config.i18n.load_path += Dir[File.join(info["path"], "config", "locales", '*.{rb,yml}')] }

      # assets
      app.config.assets.paths << Rails.root.join("app", "apps")
      app.config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
      app.config.assets.paths << File.join($camaleon_engine_dir, "app", "apps")
      app.config.assets.paths << File.join($camaleon_engine_dir, 'app', 'assets', 'fonts')
      app.config.encoding = "utf-8"

      #multiple route files
      app.routes_reloader.paths.push(File.join(engine_dir, "config", "routes", "admin.rb"))
      app.routes_reloader.paths.push(File.join(engine_dir, "config", "routes", "frontend.rb"))
      # Dir[File.join(engine_dir, "config", "routes", "*.rb")].each{|r| app.routes_reloader.paths.unshift(r) }

      # extra configuration for plugins
      app.config.eager_load_paths += %W(#{app.config.root}/app/apps/**/)
      PluginRoutes.all_plugins.each{ |plugin| app.config.paths["db/migrate"] << File.join(plugin["path"], "migrate") if Dir.exist?(File.join(plugin["path"], "migrate")) }

      # Static files
      app.middleware.use ::ActionDispatch::Static, "#{root}/public"

      # migrations checking
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
