# load all custom initializers of plugins or themes
Rails.application.config.to_prepare do |_config|
  PluginRoutes.all_apps.each do |ap|
    next unless ap['path'].present?

    f = File.join(ap['path'], 'config', 'initializer.rb')
    eval(File.read(f)) if File.exist?(f)

    f = File.join(ap['path'], 'config', 'custom_models.rb')
    eval(File.read(f)) if File.exist?(f)
  end

  # This can be overridden in the app initializer to wrap the sleep and delete_file in an async job
  CamaleonCmsUploader.delete_block do |settings, cama_uploader, file_key|
    sleep(settings[:temporal_time])
    cama_uploader.delete_file(file_key)
  end
end
