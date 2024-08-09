$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'camaleon_cms/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'camaleon_cms'
  s.version     = CamaleonCms::VERSION
  s.authors     = ['Owen Peredo Diaz']
  s.email       = ['owenperedo@gmail.com']
  s.homepage    = 'https://camaleon.website'
  s.summary     = 'Camaleon is a CMS for Ruby on Rails as an alternative to Wordpress.'
  s.description = 'Camaleon CMS is a dynamic and advanced content management system based on Ruby on Rails as an alternative to Wordpress.'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 3.0'
  s.requirements << 'rails >= 6.1'
  s.requirements << 'ruby >= 3.0'
  s.requirements << 'imagemagick'
  # s.post_install_message = "Thank you for install Camaleon CMS."

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']

  s.add_dependency 'addressable'
  s.add_dependency 'bcrypt'
  s.add_dependency 'breadcrumbs_on_rails'
  s.add_dependency 'cama_contact_form', '~> 0.1.0'
  s.add_dependency 'cama_meta_tag'
  s.add_dependency 'cancancan', '>= 2.0', '< 4'
  s.add_dependency 'dartsass-sprockets'
  s.add_dependency 'draper', '>= 4.0.2'
  s.add_dependency 'font-awesome-rails'
  s.add_dependency 'ipaddress'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'meta-tags', '~> 2.0'
  s.add_dependency 'mini_magick'
  s.add_dependency 'non-digest-assets', '~> 2.0'
  s.add_dependency 'sprockets-rails', '>= 3.5.1'
  s.add_dependency 'tinymce-rails', '< 5'
  s.add_dependency 'will_paginate'
  s.add_dependency 'will_paginate-bootstrap'

  # MEDIA MANAGER
  s.add_dependency 'aws-sdk-s3', '~> 1'

  # development dependencies
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'pry-rescue'
  s.add_development_dependency 'pry-stack_explorer'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-instafail'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'sqlite3'
end
