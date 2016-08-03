# load all custom initializers of plugins or themes
PluginRoutes.all_apps.each do |ap|
  if ap["path"].present?
    f = File.join(ap["path"], "config", "initializer.rb")
    eval(File.read(f)) if File.exist?(f)

    f = File.join(ap["path"], "config", "custom_models.rb")
    eval(File.read(f)) if File.exist?(f)
  end
end