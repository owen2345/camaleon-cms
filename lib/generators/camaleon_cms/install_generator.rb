require 'rails/generators/base'
require 'securerandom'
module CamaleonCms
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../install_template", __FILE__)
      desc "This generator create all basic Camaleon CMS structure."

      def create_initializer_file
        copy_file "system.json", "config/system.json"
        copy_file "plugin_routes.rb", "lib/plugin_routes.rb"
        Dir.mkdir Rails.root.join("app", "apps").to_s unless Dir.exist?(Rails.root.join("app", "apps").to_s)
        directory("apps", "app/apps")
        directory( File.join($camaleon_engine_dir, 'app/apps/themes').to_s, 'app/apps/themes')

        sprokects_4_or_newer = defined?(Sprockets::BabelProcessor)
        if sprokects_4_or_newer
          assets_config_dir = Rails.root.join('app', 'assets', 'config')
          FileUtils.makedirs(assets_config_dir)
          assets_config_file = assets_config_dir.join('manifest.js')
          FileUtils.touch(assets_config_file) unless File.file?(assets_config_file)
          append_to_file assets_config_file, <<~ASSETS
  
                                               // Camaleon CMS assets
                                               //= link camaleon-cms.js
                                               //= link_tree ../../apps/themes/camaleon_first/assets
                                               //= link_tree ../../apps/themes/default/assets
                                               //= link_tree ../../apps/themes/new/assets
                                             ASSETS
          append_to_file Rails.root.join('config', 'initializers', 'assets.rb'),
            <<~PRECOMPILE_MANIFEST
  
              Rails.application.config.assets.precompile += %w( manifest.js )
            PRECOMPILE_MANIFEST
        end

        append_to_file 'Gemfile' do
          "\n\n#################### Camaleon CMS include all gems for plugins and themes #################### \nrequire './lib/plugin_routes' \ninstance_eval(PluginRoutes.draw_gems)"
        end
      end
    end
  end
end
