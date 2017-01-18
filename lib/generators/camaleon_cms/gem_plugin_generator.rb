require 'rails/generators/base'
require 'securerandom'
module CamaleonCms
  module Generators
    class GemPluginGenerator < Rails::Generators::Base
      source_root File.expand_path("../gem_plugin_template", __FILE__)
      argument :plugin_name, :type => :string, :default => "my_plugin"
      desc "This generator create all basic gem plugin structure."

      def create_initializer_file
        plugin_dir = Rails.root.join("apps", "plugins", get_plugin_name).to_s
        if behavior == :revoke
          FileUtils.rm_r(plugin_dir)
          append_to_file Rails.root.join("Gemfile") do
            "\n\ngem '#{get_plugin_name}', path:  '#{plugin_dir}/'"
          end
        else
          plugin_app = File.join($camaleon_engine_dir, "lib", "generators", "camaleon_cms", "gem_plugin_#{get_plugin_name}")
          FileUtils.rm_r(plugin_app) if Dir.exist?(plugin_app)

          FileUtils.mkdir_p(plugin_dir)
          system("cd #{Rails.root} & rails plugin new apps/plugins/#{get_plugin_name} --full")

          FileUtils.cp_r(File.join($camaleon_engine_dir, "lib", "generators", "camaleon_cms", "gem_plugin_template"), plugin_app)

          # tmp copy
          helper_path = File.join(plugin_app, "app", "helpers", "plugins", get_plugin_name)
          model_path = File.join(plugin_app, "app", "models", "plugins", get_plugin_name)
          views_path = File.join(plugin_app, "app", "views", "plugins", get_plugin_name)
          controller_path = File.join(plugin_app, "app", "controllers", "plugins", get_plugin_name)
          FileUtils.mv(File.join(plugin_app, "app", "controllers", "plugins", "my_plugin"), controller_path) rescue nil
          FileUtils.mv(File.join(plugin_app, "app", "helpers", "plugins", "my_plugin"), helper_path) rescue nil
          FileUtils.mv(File.join(plugin_app, "app", "models", "plugins", "my_plugin"), model_path) rescue nil
          FileUtils.mv(File.join(plugin_app, "app", "views", "plugins", "my_plugin"), views_path) rescue nil
          FileUtils.mv(File.join(plugin_app, "app", "assets", "images", "plugins", "my_plugin"), File.join(plugin_app, "app", "assets", "images", "plugins", get_plugin_name)) rescue nil
          FileUtils.mv(File.join(plugin_app, "app", "assets", "javascripts", "plugins", "my_plugin"), File.join(plugin_app, "app", "assets", "javascripts", "plugins", get_plugin_name)) rescue nil
          FileUtils.mv(File.join(plugin_app, "app", "assets", "stylesheets", "plugins", "my_plugin"), File.join(plugin_app, "app", "assets", "stylesheets", "plugins", get_plugin_name)) rescue nil

          # configuration
          t = fix_text(File.read(File.join(plugin_app, "config", "camaleon_plugin.json")))
          File.open(File.join(plugin_app, "config", "camaleon_plugin.json"), "w"){|f| f << t }

          # helper
          t = fix_text(File.read(File.join(helper_path, "main_helper.rb")))
          File.open(File.join(helper_path, "main_helper.rb"), "w"){|f|  f << t }

          # controllers
          t = fix_text(File.read(File.join(controller_path, "admin_controller.rb")))
          File.open(File.join(controller_path, "admin_controller.rb"), "w"){|f| f << t }
          t = fix_text(File.read(File.join(controller_path, "front_controller.rb")))
          File.open(File.join(controller_path, "front_controller.rb"), "w"){|f| f << t }

          # models
          model_file = File.join(model_path, "my_plugin.rb")
          t = fix_text(File.read(model_file))
          File.open(model_file, "w"){|f| f << t }
          FileUtils.mv(model_file, File.join(File.dirname(model_file), "#{get_plugin_name}.rb")) rescue nil


          directory(plugin_app, plugin_dir)
          gsub_file File.join(plugin_dir, "config", "routes.rb"), "end" do
            "
    scope PluginRoutes.system_info[\"relative_url_root\"] do
      scope '(:locale)', locale: /\#{PluginRoutes.all_locales}/, :defaults => {  } do
        # frontend
        namespace :plugins do
          namespace '#{get_plugin_name}' do
            get 'index' => 'front#index'
          end
        end
      end

      #Admin Panel
      scope :admin, as: 'admin', path: PluginRoutes.system_info['admin_path_name'] do
        namespace 'plugins' do
          namespace '#{get_plugin_name}' do
            controller :admin do
              get :index
              get :settings
              post :save_settings
            end
          end
        end
      end

      # main routes
      #scope '#{get_plugin_name}', module: 'plugins/#{get_plugin_name}/', as: '#{get_plugin_name}' do
      #  Here my routes for main routes
      #end
    end
  end"
          end

          append_to_file Rails.root.join("Gemfile") do
            "\n\ngem '#{get_plugin_name}', path:  '#{plugin_dir}/'"
          end

          # destroy non used files
          FileUtils.rm_r(plugin_app)
          FileUtils.rm_r(File.join(plugin_dir, "app", "assets", "images", get_plugin_name))
          FileUtils.rm_r(File.join(plugin_dir, "app", "assets", "javascripts", get_plugin_name))
          FileUtils.rm_r(File.join(plugin_dir, "app", "assets", "stylesheets", get_plugin_name))

          # remove TODO text from gem
          gemspec_file = File.join(plugin_dir, "#{get_plugin_name}.gemspec")
          t = File.read(gemspec_file).gsub("TODO", "")
          File.open(gemspec_file, "w"){|f| f << t }
        end
      end

      def fix_text(text = "")
        text.gsub("pluginTitle", get_plugin_title).gsub("PluginClass", get_plugin_class).gsub("pluginKey", get_plugin_name)
      end

      def self.next_migration_number(dir)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      private
      def get_plugin_name
        plugin_name.underscore.singularize
      end

      def get_plugin_title
        plugin_name.titleize
      end
      def get_plugin_class
        get_plugin_name.classify
      end

    end
  end
end
