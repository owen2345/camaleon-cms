require 'rubygems'
require 'bcrypt'
require 'cancancan'
require 'meta-tags'
require 'mini_magick'
require 'will_paginate'
require 'will_paginate-bootstrap'
require 'breadcrumbs_on_rails'
require 'aws-sdk-s3'
require 'font-awesome-rails'
require 'tinymce-rails'
require 'jquery-rails'
require 'dartsass-sprockets'
require 'cama_contact_form'
require 'cama_meta_tag'

# `factory_bot_rails` gem can be added to test, development and/or other environments in the main app, containing the
# `camaleon_cms` gem.
# So, being unknown, whether it is defined or not, we're trying requiring the gem, using `rescue` in case of failures.
begin
  require 'factory_bot_rails'
rescue LoadError
  # do nothing
end

$camaleon_engine_dir = File.expand_path('../..', __dir__)
require File.join($camaleon_engine_dir, 'lib', 'plugin_routes').to_s
Dir[File.join($camaleon_engine_dir, 'lib', 'ext', '**', '*.rb')].sort.each { |f| require f }
require 'draper'

module CamaleonCms
  class Engine < ::Rails::Engine
    config.generators do |g|
      g.test_framework :rspec
    end
    config.before_initialize do |app|
      if app.respond_to?(:console)
        app.console do
          # puts "******** Camaleon CMS: ********"
          # puts "- include CamaleonCms::SiteHelper"
          # puts "- $current_site = CamaleonCms::Site.first.decorate"
        end
      end
    end

    initializer :append_migrations do |app|
      engine_dir = File.expand_path('../..', __dir__)
      translation_files = Dir[File.join($camaleon_engine_dir, 'config', 'locales', '**', '*.{rb,yml}')]
      PluginRoutes.all_apps.each do |info|
        translation_files += Dir[File.join(info['path'], 'config', 'locales', '*.{rb,yml}')]
      end
      app.config.i18n.enforce_available_locales = false
      app.config.i18n.load_path.unshift(*translation_files)

      # assets
      app.config.assets.paths << Rails.root.join('app', 'apps')
      app.config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
      app.config.assets.paths << File.join($camaleon_engine_dir, 'app', 'apps')
      app.config.assets.paths << File.join($camaleon_engine_dir, 'app', 'assets', 'fonts')
      app.config.encoding = 'utf-8'

      # add prefix url, like: https://localhost.com/blog/
      # config.action_controller.relative_url_root = PluginRoutes.system_info["relative_url_root"] if PluginRoutes.system_info["relative_url_root"].present?

      # multiple route files
      app.routes_reloader.paths.push(File.join(engine_dir, 'config', 'routes', 'admin.rb'))
      app.routes_reloader.paths.push(File.join(engine_dir, 'config', 'routes', 'frontend.rb'))
      # Dir[File.join(engine_dir, "config", "routes", "*.rb")].each{|r| app.routes_reloader.paths.unshift(r) }

      # extra configuration for plugins
      app.config.eager_load_paths += %W[#{app.config.root}/app/apps/]
      if PluginRoutes.static_system_info['auto_include_migrations']
        PluginRoutes.all_plugins.each do |plugin|
          app.config.paths['db/migrate'] << File.join(plugin['path'], 'migrate') if Dir.exist?(File.join(
                                                                                                 plugin['path'], 'migrate'
                                                                                               ))
          app.config.paths['db/migrate'] << File.join(plugin['path'], 'db', 'migrate') if Dir.exist?(File.join(
                                                                                                       plugin['path'], 'db', 'migrate'
                                                                                                     ))
        end
      end

      # Static files
      app.middleware.use ::ActionDispatch::Static, "#{root}/public"

      # migrations checking
      if PluginRoutes.static_system_info['auto_include_migrations'] && !(app.root.to_s.match root.to_s)
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end

    if defined?(FactoryBotRails)
      config.factory_bot.definition_file_paths +=
        [File.expand_path('../../spec/factories', __dir__)]
    end
  end
end
