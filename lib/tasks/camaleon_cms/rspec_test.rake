namespace :camaleon_cms do
  desc "Process all rspec features of camaleon cms"
  # Please add this gems in your Gemfile and run: rake camaleon_cms:rspec
  # group :test do
  #   gem 'mysql2', '~> 0.3.11'
  #   gem 'rspec-rails', '~> 3.0'
  #   gem 'capybara'
  #   gem "selenium-webdriver"
  # end
  # After run: rails generate rspec:install, support folder
  # copy rails helper, rspec_helper,
  task :rspec, [:file] => :environment do |task, args|
    if args.file.present?
      puts "************* running: #{"rspec #{File.join($camaleon_engine_dir, args.file)}"}"
      system("rspec #{File.join($camaleon_engine_dir, args.file)}")
    else
      Dir[File.join($camaleon_engine_dir, "spec", "features", "*.rb")].each{|p| system("rspec #{p}") }
    end
  end
end