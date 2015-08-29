PluginRoutes.all_enabled_apps.each do |ap|
  f = File.join(ap["path"], "config", "initializer.rb")
  eval(File.read(f)) if File.exist?(f)
end