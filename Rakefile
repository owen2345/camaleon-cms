begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

APP_RAKEFILE = File.expand_path('spec/dummy/Rakefile', __dir__)
load 'rails/tasks/engine.rake'

# Deliberately no Bundler::GemHelper.install_tasks: its `rake release` would tag `v<version>` and
# push a gem that none of the release checks had seen. Releases go through the Release workflow —
# see docs/releasing.md, which also covers building and publishing by hand.

require 'rspec/core/rake_task'

desc 'Run all specs in spec directory (excluding plugin specs)'
RSpec::Core::RakeTask.new(spec: 'app:db:test:prepare')

task default: :spec
