namespace :camaleon_cms do
  desc 'Copy Camaleon CMS and all plugins migrations to migration folder'
  task generate_migrations: :environment do
    PluginRoutes.all_plugins.each do |plugin|
      ENV['FROM'] = plugin['KEY']
      if Rake::Task.task_defined?('railties:install:migrations')
        Rake::Task['railties:install:migrations'].invoke
      else
        Rake::Task['app:railties:install:migrations'].invoke
      end
    end
  end
end
