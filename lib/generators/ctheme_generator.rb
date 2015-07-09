class CthemeGenerator < Rails::Generators::Base
  source_root File.expand_path("../ctheme_template", __FILE__)
  argument :theme_name, :type => :string, :default => "my_theme"
  desc "This generator create basic theme structure"

  def create_initializer_file
    if behavior == :revoke
      if PluginRoutes.theme_info(get_theme_name).present?
        PluginRoutes.destroy_theme(get_theme_name)
        puts "Theme destroyed successfully"
      else
        puts "This theme doesn't exist"
      end

    else

      if PluginRoutes.all_themes.include?(PluginRoutes.theme_info(get_theme_name))
        puts "This theme already exist"
      else

        # helpers + controllers
        plugin_app = Rails.root.join("lib", "generators", "ctheme_template", "app_#{get_theme_name}")
        plugin_folder = File.join(plugin_app, "apps", "themes", get_theme_name)

        # tmp copy
        FileUtils.cp_r(Rails.root.join("lib", "generators", "ctheme_template", "app"), plugin_app)
        FileUtils.mv(File.join(plugin_app, "apps", "themes", "my_theme"), plugin_folder) rescue nil

        # configuration
        t = fix_text(File.read(File.join(plugin_folder, "config", "config.json")))
        File.open(File.join(plugin_folder, "config", "config.json"), "w"){|f| f << t }

        # helper
        t = fix_text(File.read(File.join(plugin_folder, "main_helper.rb")))
        File.open(File.join(plugin_folder, "main_helper.rb"), "w"){|f|  f << t }


        directory("app_#{get_theme_name}", Rails.root.join("app"))
        FileUtils.rm_r(plugin_app)
      end
    end
  end

  def fix_text(text = "")
    text.gsub("{theme_title}", get_theme_title).gsub("{theme_class}", get_theme_class).gsub("{theme_key}", get_theme_name)
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