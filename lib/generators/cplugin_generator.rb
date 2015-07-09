class CpluginGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path("../cplugin_template", __FILE__)
  argument :plugin_name, :type => :string, :default => "my_plugin"
  desc "This generator create word rails plugin structure"

  def create_initializer_file
    if behavior == :revoke
      if PluginRoutes.plugin_info(get_plugin_name).present?
        PluginRoutes.destroy_plugin(get_plugin_name)
        puts "Plugin destroyed successfully"
      else
        puts "This plugins doesn't exist"
      end

    else

      if PluginRoutes.all_plugins.include?(PluginRoutes.plugin_info(get_plugin_name))
        puts "This plugins already exist"
      else

        # helpers + controllers
        plugin_app = Rails.root.join("lib", "generators", "cplugin_template", "app_#{get_plugin_name}")
        plugin_folder = File.join(plugin_app, "apps", "plugins", get_plugin_name)

        # tmp copy
        FileUtils.cp_r(Rails.root.join("lib", "generators", "cplugin_template", "app"), plugin_app)
        FileUtils.mv(File.join(plugin_app, "apps", "plugins", "my_plugin"), plugin_folder) rescue nil

        # configuration
        t = fix_text(File.read(File.join(plugin_folder, "config", "config.json")))
        File.open(File.join(plugin_folder, "config", "config.json"), "w"){|f| f << t }

        # helper
        t = fix_text(File.read(File.join(plugin_folder, "main_helper.rb")))
        File.open(File.join(plugin_folder, "main_helper.rb"), "w"){|f|  f << t }

        # controllers
        t = fix_text(File.read(File.join(plugin_folder, "admin_controller.rb")))
        File.open(File.join(plugin_folder, "admin_controller.rb"), "w"){|f| f << t }
        t = fix_text(File.read(File.join(plugin_folder, "front_controller.rb")))
        File.open(File.join(plugin_folder, "front_controller.rb"), "w"){|f| f << t }

        # models
        model_file = File.join(plugin_folder, "models", "my_plugin.rb")
        t = fix_text(File.read(model_file))
        File.open(model_file, "w"){|f| f << t }
        FileUtils.mv(model_file, File.join(File.dirname(model_file), "#{get_plugin_name}.rb")) rescue nil

        #views
        views_folder = File.join(plugin_folder, "views")

        directory("app_#{get_plugin_name}", Rails.root.join("app"))
        FileUtils.rm_r(plugin_app)

      end
    end

  end

  def fix_text(text = "")
    text.gsub("{plugin_title}", get_plugin_title).gsub("{plugin_class}", get_plugin_class).gsub("{plugin_key}", get_plugin_name)
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