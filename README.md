![](https://img.shields.io/badge/Rails-4%2B-green.svg)
![](https://img.shields.io/badge/Ruby-1.9.3%2B-green.svg)
![](https://img.shields.io/badge/Mysql-100%-green.svg)
![](https://img.shields.io/badge/Sqlite-100%-green.svg)
![](https://img.shields.io/badge/Postgres-100%-green.svg)
![](https://img.shields.io/badge/Tests-In_Progress-red.svg)
![](https://img.shields.io/badge/Docs-90%-orange.svg)
![](https://img.shields.io/badge/Support-Inmediate-green.svg)

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/owen2345/Camaleon-CMS-Sample)   
# CAMALEON CMS
![](http://camaleon.tuzitio.com/media/132/logo2.png)

# Requirements
* Rails 4.1+
* MySQL 5+ or SQlite or PostgreSQL
* Ruby 1.9.3+
* Imagemagick

# Installation
* Install Ruby on Rails 4.1+
  [Visit here.](http://railsapps.github.io/installing-rails.html)
* Create your rails project

  ```
  rails new my_project
  ```
* Add the gem in your Gemfile

  ```
  gem 'camaleon_cms'
  ```
* Install the gem

  ```
  bundle install
  ```
* Install the CMS (This will copy some basic templates and plugins in your project)

  ```
  rails generate camaleon_cms:install
  ```
* Install required Gems for CMS and basic plugins

  ```
  bundle install
  ```
* Create database structure

  ```
  rake db:migrate
  ```
* Start your server

  ```
  rails server # and then go to your browser http://localhost:3000/
  ```

  Temporarily download additional plugins (Plugin/Theme store in testing...) from:  [Here.](https://github.com/owen2345/Camaleon-CMS-Sample/tree/master/app/apps/plugins)

# Camaleon CMS (It adapts to your needs)
Camaleon CMS is a dynamic and advanced content management system based on Ruby on Rails 4 and Ruby 1.9.3+. This CMS is an alternative to wordpress for Ruby on Rails developers to manage advanced contents easily.  
Camaleon CMS is a flexible manager where you can build your custom content structure without coding anything by custom fields and custom contents type.

## Camaleon CMS is FREE and Open source
It was released on July, 2015 and tested previously with more than 20 projects by 6 months and on august 22, 2015 was published as a gem.

![](http://camaleon.tuzitio.com/media/132/multi-language.png)

## With Camaleon you can do:
* Multiples sites in the same installation
* Multilanguage sites
* Extend or customize the functionalities by plugins
* Manage your content visualization by themes
* Advanced User roles
* Other features:
  - Shortcodes
  - Widgets
  - Drag and Drop / Sortable / Multi level menus
  - Templates for pages
  - Easy migration from wordpress

## Some features are:
* Easy administration
  Camaleon CMS permit you to adapt the CMS to all your needs and not you adapt to the CMS.
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
  Customize your content for Desktop, Mobile and Tablet
* SEO & HTML5
  - Automatic Sitemap generations
  - Seo Configuration
  - Seo for social media
  - Customize your content for Desktop, Mobile and Tablet
  - All generated content is compatible with HTML5


## Camaleon CMS come with basic and important plugins like:
* Ecommerce
* Visibility content
* Web attack control
* Contact forms
* Cache content
* Content reorder
* many others [here.](https://github.com/owen2345/Camaleon-CMS-Sample)

## Demonstration
* [Camaleon Server](http://camaleon.tuzitio.com/plugins/demo_manage/)
* [Deploy in Heroku](https://heroku.com/deploy?template=https://github.com/owen2345/Camaleon-CMS-Sample)

## Support
If you have problems, please enter an issue [here.](https://github.com/owen2345/camaleon-cms/issues)  
If you need support, need some extra functionality or need plugins, please contact us on:
* Site: http://camaleon.tuzitio.com/
* Email: owenperedo@gmail.com
* Skype: owen-2345

## Author
Owen Peredo Diaz

## License
http://camaleon.tuzitio.com/license.html/

## Coming soon
* Plugins Store (anybody can upload plugins to this store)
* Themes Store (anybody can upload themes to this store)
* Create more basic plugins
* Documentation and Videos

## Contributing
* Fork it.
* Create a branch (git checkout -b my_feature_branch)
* Commit your changes (git commit -am "Added a sweet feature")
* Push to the branch (git push origin my_feature_branch)
* Create a pull request from your branch into master (Please be sure to provide enough detail for us to cipher what this change is doing)

Visit the web site for more information: http://camaleon.tuzitio.com/