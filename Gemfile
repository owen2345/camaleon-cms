source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2'

group :production do
  gem 'pg' # Use mysql as the database for Active Record
end
group :development, :test do
  gem 'sqlite3' # for sqlite uncomment this and comment mysql2
  gem 'rubocop'
end

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster.
# Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 1.2'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

##################### CUSTOM GEMS ######################
gem 'protected_attributes' # adds mass assignment protection for Rails 4
gem 'bcrypt' # rails password security
gem 'mini_magick' # image library (resize, crop, captcha, ..)
gem 'will_paginate' # list pagination
gem 'will_paginate-bootstrap' # list pagination for bootstrap

# others
gem 'el_finder' # media manager
gem 'el_finder_aws_s3' #s3
#FIXME remove after
gem 'net-ftp-list'

gem 'cancancan', '~> 1.10' # user permissions
gem 'meta-tags' # seo meta tags generatos
gem 'draper', '~> 1.3' # decorators

gem 'rufus-scheduler', '~> 3.1.1' # crontab
gem 'dynamic_sitemaps' # sitemaps
gem 'actionpack-page_caching' # page caching
gem 'mobu' # mobile detect

# include all gems for plugins and themes
require './lib/plugin_routes'
instance_eval(PluginRoutes.draw_gems)

# fix for windows users
group :development do
  gem 'thin', platforms: [:mingw, :mswin]
  gem 'tzinfo-data', platforms: [:mingw, :mswin]
end
##################### END CUSTOM GEMS ######################

