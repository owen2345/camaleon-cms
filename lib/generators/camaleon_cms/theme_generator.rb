require 'rails/generators/base'
require 'securerandom'
module CamaleonCms
  module Generators
    class ThemeGenerator < Rails::Generators::Base
      source_root File.expand_path("../theme_template", __FILE__)
      argument :theme_name, :type => :string, :default => "my_theme"
      desc "This generator create basic theme structure"

      def create_initializer_file
        theme_folder = Rails.root.join('app', 'apps', 'themes', get_theme_name)
        if behavior == :revoke
          if Dir.exist?(theme_folder)
            FileUtils.rm_rf(theme_folder)
            puts "Theme destroyed successfully"
          else
            puts "This theme doesn't exist"
          end

        else

          if Dir.exist?(theme_folder)
            puts "This theme already exist"
          else

            theme_folder = Rails.root.join('app', 'apps', 'themes', get_theme_name)
            return puts ("There is already a theme with the same name in: #{theme_folder}") if Dir.exist?(theme_folder)

            # tmp copy
            FileUtils.mkdir_p(theme_folder)
            FileUtils.copy_entry(File.join($camaleon_engine_dir, "lib", "generators", "camaleon_cms", 'theme_template'), theme_folder)

            # configuration
            t = fix_text(File.read(File.join(theme_folder, "config", "config.json")))
            File.open(File.join(theme_folder, "config", "config.json"), "w"){|f| f << t }

            # helper
            t = fix_text(File.read(File.join(theme_folder, "main_helper.rb")))
            File.open(File.join(theme_folder, "main_helper.rb"), "w"){|f|  f << t }
            puts "Theme successfully created in: #{theme_folder}"
          end
        end
      end

      def fix_text(text = "")
        text.gsub("themeTitle", get_theme_title).gsub("ThemeClass", get_theme_class).gsub("themeKey", get_theme_name)
      end

      def self.next_migration_number(dir)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      private
      def get_theme_name
        theme_name.underscore.singularize
      end

      def get_theme_title
        theme_name.titleize
      end
      def get_theme_class
        get_theme_name.classify
      end
    end
  end
end