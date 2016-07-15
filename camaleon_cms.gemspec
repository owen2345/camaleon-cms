$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "camaleon_cms/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "camaleon_cms"
  s.version     = CamaleonCms::VERSION
  s.authors     = ["Owen Peredo Diaz"]
  s.email       = ["owenperedo@gmail.com"]
  s.homepage    = "http://camaleon.tuzitio.com"
  s.summary     = "Camaleon is a cms for Ruby on Rails 4 as an alternative to wordpress."
  s.description = "Camaleon CMS is a dynamic and advanced content management system based on Ruby on Rails 4 as an alternative to Wordpress."
  s.license     = "MIT"

  s.required_ruby_version = '>= 1.9.3'
  s.requirements << 'rails >= 4.1'
  s.requirements << 'ruby >= 1.9.3'
  s.requirements << 'imagemagick'
  # s.post_install_message = "Thank you for install Camaleon CMS."

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "public/**/*"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency 'bcrypt'
  s.add_dependency 'cancancan', '~> 1.10'
  s.add_dependency 'draper', '~> 1.3'
  s.add_dependency 'meta-tags', '~> 2.0'
  s.add_dependency 'mini_magick'
  # s.add_dependency 'mobu'
  s.add_dependency 'will_paginate'
  s.add_dependency 'will_paginate-bootstrap'
  s.add_dependency 'breadcrumbs_on_rails'
  s.add_dependency 'font-awesome-rails'
  s.add_dependency 'tinymce-rails', '~> 4.3'

  s.add_dependency 'cama_contact_form', '~> 0.0.11'

  # MEDIA MANAGER
  s.add_dependency 'aws-sdk', '~> 2'
end
