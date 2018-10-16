# CAMALEON CMS

![](http://camaleon.tuzitio.com/media/132/logo2.png)

[![Build Status](https://travis-ci.org/owen2345/camaleon-cms.svg?branch=master)](https://travis-ci.org/owen2345/camaleon-cms)
![](https://img.shields.io/badge/Support-Immediate-green.svg)

[Website](http://camaleon.tuzitio.com/)

[Documentation](http://camaleon.tuzitio.com/docs.html)

[Demonstration](http://camaleon.tuzitio.com/plugins/demo_manage/)

## Sponsor

[ButterCMS](https://buttercms.com/?utm_source=github&utm_medium=sponsorship-link&utm_campaign=camaleon) is an API-based CMS and blogging platform built for developers.

## About

Camaleon CMS is a dynamic and advanced content management system based on Ruby on Rails that adapts to your needs. This CMS is an alternative to Wordpress for Ruby on Rails developers to manage advanced content easier.

Camaleon CMS is a flexible manager where you can build your custom content structure without coding anything by custom fields and custom contents type.

To download or publish themes go to Theme store:
http://camaleon.tuzitio.com/store/themes

To download or publish plugins go to Plugin store:
http://camaleon.tuzitio.com/store/plugins

![](screenshot.png)

## With Camaleon you can do:
* Multiples sites in the same installation
* Multi-language sites
* Design and create the architecture of your project without programming by dynamic contents and fields
* Extend or customize the functionalities by plugins
* Manage your content visualization by themes
* Advanced User roles
* Integrate into existent Rails projects
* Other features:
  - Shortcodes
  - Widgets
  - Drag and Drop / Sortable / Multi level menus
  - Templates/Layouts for pages
  - Easy migration from Wordpress

## Some features
* Integrate into existent Ruby on Rails Projects
* Easy administration
  Camaleon CMS permits you to adapt the CMS to all your needs and not you adapt to the CMS.
I.E. you can create your custom architecture with all attributes that you need for each kind of content.
* Security
  - Remote code execution
  - SQL injections
  - Advanced sessions security
  - Cross Site Scripting
  - Control of abusive requests
  - Cross-Site Request Forgery
* Site Speed
  Camaleon CMS include a lot of cache strategies to optimize the site access velocity:
    - Cache contents
    - Cache queries
    - Manifests (compress and join asset files)
    - Customize your content visualization for Desktop, Mobile and Tablet
* SEO & HTML5
  - Sitemap generations
  - Seo configuration
  - Seo for social media
  - All generated content is compatible with HTML5 and Bootstrap 3

## Camaleon CMS has many useful plugins such as:
* E-commerce
* Contact Forms
* Email Subscriptions
* SEO
* Content Cache
* Translation Management
* Web Attack Control
* Import / Export
* and many more in the Plugin store: http://camaleon.tuzitio.com/store/plugins

## Requirements
* Rails 4.2 or 5+
* PostgreSQL, MySQL 5+ or SQlite
* Ruby 2.2+
* Imagemagick

## Installation
* Install Ruby on Rails
* Create your rails project

  ```
  rails new my_project
  ```
* Add the gem in your Gemfile 

  ```
  gem "camaleon_cms",  '>= 2.4.5' # (Current stable versions are 2.4.4.5, 2.4.3.10, 2.3.6, 2.2.1, 2.1.1)
  # OR
  # gem "camaleon_cms", github: 'owen2345/camaleon-cms' # latest development version

  # gem 'draper', '~> 3' # for Rails 5+
  ```

* Install required Gem and dependencies

  ```
  bundle install
  ```
* Camaleon CMS Installation

  ```
  rails generate camaleon_cms:install
  ```
* (Optional) Before continue you can configure your CMS settings in (my_app/config/system.json), [here](config/system.json) you can see the full settings.
* Create database structure
  ```
  rake camaleon_cms:generate_migrations
  # before running migrations you can customize copied migration files
  rake db:migrate
  ```

* Start your server

  ```
  rails server
  ```

* Go to your browser and visit http://localhost:3000/

## Sample App / Demonstration
* [Camaleon Server (current version)](http://camaleon.tuzitio.com/plugins/demo_manage/)
* [Sample App](https://github.com/owen2345/Camaleon-CMS-Sample)
* [Deploy Sample App in Heroku](https://heroku.com/deploy?template=https://github.com/owen2345/Camaleon-CMS-Sample)

## Support
If you have problems, please enter an issue [here.](https://github.com/owen2345/camaleon-cms/issues)
If you need support, need some extra functionality or need plugins, please contact us on:
* Site: http://camaleon.tuzitio.com/
* Email: owenperedo@gmail.com
* Skype: owen-2345
* Stack Overflow: Use "camaleon" as tag to ask questions related to this CMS (don't forget to include cms version + rails version).
* Gitter: https://gitter.im/camaleoncms/Lobby

## Author
Owen Peredo Diaz

## License
http://camaleon.tuzitio.com/license.html

## Testing
* Init DB
```
RAILS_ENV=test bundle exec rake app:db:migrate
RAILS_ENV=test bundle exec rake app:db:test:prepare
```
* Configure/Install Poltergeist and change your phanthomjs path in spec/spec_helper.rb

* Run testing
```
bundle exec rspec
```

## Contributing
* Fork it.
* Create a branch (git checkout -b my_feature_branch)
* Commit your changes (git commit -am "Added a sweet feature")
* Push to the branch (git push origin my_feature_branch)
* Create a pull request from your branch into master (Please be sure to provide enough detail for us to understand what this change is doing)

## Camaleon CMS is FREE and Open source
It was released on July, 2015 and tested previously with more than 20 projects by 6 months and on August 22, 2015 was published as a gem.

## Version History
Previous stable version (v1.x): https://github.com/owen2345/camaleon-cms/tree/version_1x

http://camaleon.tuzitio.com/version-history.html
