# CAMALEON CMS

![](http://camaleon.tuzitio.com/media/132/logo2.png)

[![Build Status](https://travis-ci.org/owen2345/camaleon-cms.svg?branch=master)](https://travis-ci.org/owen2345/camaleon-cms)
![](https://img.shields.io/badge/Support-Immediate-green.svg)

[Website](http://camaleon.tuzitio.com/)

[Documentation](http://camaleon.tuzitio.com/docs.html)

[Demonstration](http://camaleon.tuzitio.com/plugins/demo_manage/)

## About

Camaleon CMS is a dynamic and advanced content management system based on Ruby on Rails that adapts to your needs. This CMS is an alternative to Wordpress for Ruby on Rails developers to manage advanced content easier.

Camaleon CMS is a flexible manager where you can build your custom content structure without coding anything by custom fields and custom contents type.

To download or publish themes go to Theme store:
http://camaleon.tuzitio.com/store/themes

To download or publish plugins go to Plugin store:
http://camaleon.tuzitio.com/store/plugins

![](screenshot.png)

## With Camaleon you can do:
* Integrate into existing Rails projects
* Multiples sites in the same installation
* Multi-language sites
* Design and create the architecture of your project without programming by dynamic contents and fields
* Extend or customize the functionality using plugins
* Manage your content visualization using themes
* Easier administration. Camaleon CMS permits you to adapt the CMS to all your needs and not you adapt to the CMS. You can create your custom architecture with any custom attributes that you need for all content types.

## Some features
* Camaleon CMS is FREE and Open source
* Shortcodes
* Widgets
* Drag and Drop / Sortable / Multi level menus
* Templates/Layouts for pages
* Advanced User roles
* File Uploads with built in Local and Amazon S3 support
* Easy migration from Wordpress
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

## Camaleon CMS has many useful Plugins such as:
* Content Cache (Included By Default)
* Web Attack Control (Included By Default)
* Post Visibility (Included By Default)
* Contact Forms (Included By Default) - https://github.com/owen2345/cama_contact_form
* SEO (Included By Default) - https://github.com/owen2345/camaleon-cms-seo
* E-commerce - https://github.com/owen2345/camaleon-ecommerce
* Language / Translation Editor - https://github.com/owen2345/camaleon-cms-language-editor
* Subscriber (Email Subscriptions) - https://github.com/owen2345/cama_subscriber
* Stripe Donation - https://github.com/owen2345/cama-stripe-donation
* Star Rating - https://github.com/aspirewit/camaleon_cms_rating
* Post Order - https://github.com/owen2345/camaleon-post-order-plugin
* Post Created At - https://github.com/owen2345/camaleon_post_created_at
* Post Clone - https://github.com/owen2345/camaleon-post-clone
* Sitemap Customizer - https://github.com/brian-kephart/camaleon_sitemap_customizer
* Image Optimizer - https://github.com/brian-kephart/camaleon_image_optimizer
* Import / Export - https://github.com/owen2345/camaleon_export_import
* Lightbox - https://github.com/owen2345/CamaImageLightbox
* Autocomplete - https://github.com/gaelfokou/cama_autocomplete
* Permissions for External Menus - https://github.com/owen2345/cama_external_menu
* TinyMCE Template Integration - https://github.com/owen2345/Camaleon-Tinymce-Templates
* Download Manager - https://github.com/max2320/camaleon-download
* OAuth - https://github.com/owen2345/camaleon_oauth
* Visual Editor - Paid Plugin ($) - http://camaleon.tuzitio.com/store/plugins/camaleon_editor
* Spree Commerce Integration - Paid Plugin ($) - http://camaleon.tuzitio.com/store/plugins/camaleon-spree
* Admin AJAX - Paid Plugin ($) - http://camaleon.tuzitio.com/store/plugins/admin_ajax
* **See here for a complete Gemfile**: https://github.com/owen2345/camaleon-cms/blob/master/docs/example_gemfile.rb

## Camaleon CMS has many useful frontend Themes such as:
* Default Theme (Built in)
* Clean Theme (Built in)
* Wordpress Theme (Built in)
* eCommerce - https://github.com/owen2345/cama-ecommerce-theme
* eFashion - http://camaleon.tuzitio.com/store/themes/eFashion (Github: https://github.com/mazharoddin/camaleon-cms-efashion)
* Shoppy - http://camaleon.tuzitio.com/store/themes/shoppy (Github: https://github.com/mazharoddin/camaleon-cms-shoppy)
* CV - Paid Theme ($) - http://camaleon.tuzitio.com/store/themes/cv
* Camaleon Site - Paid Them ($) - http://camaleon.tuzitio.com/store/themes/camaleon_cms
* Sky - Paid Theme ($) - http://camaleon.tuzitio.com/store/themes/sky


## Requirements
* Rails 4.2 or 5+
* PostgreSQL, MySQL 5+ or SQlite
* Ruby 2.2+
* Imagemagick

## Installation
* Install Ruby on Rails
* Create your rails project

  ```bash
  rails new my_project
  ```
* Add the gem in your Gemfile

  ```ruby
  gem "camaleon_cms",  '>= 2.4.6.1' # (Current stable versions are 2.5.0, 2.4.4.5, 2.4.3.10, 2.3.6, 2.2.1)
  # OR
  # gem "camaleon_cms", github: 'owen2345/camaleon-cms' # latest development version

  # gem 'draper', '~> 3' # for Rails 5+
  
  # For Ruby version < 2.5 
  # gem 'sprockets', '< 4' # Sprockets 4 requires Ruby version >= 2.5 
  ```

* Install required Gem and dependencies

  ```bash
  bundle install
  ```

* Camaleon CMS Installation

  ```bash
  rails generate camaleon_cms:install
  ```
* (Optional) Before continue you can configure your CMS settings in (my_app/config/system.json), [here](config/system.json) you can see the full settings.
* Create database structure
  ```bash
  rake camaleon_cms:generate_migrations
  # before running migrations you can customize copied migration files
  rake db:migrate
  ```

* Start your server

  ```bash
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
* Gitter: https://gitter.im/camaleoncms/Lobby
* Email: owenperedo@gmail.com
* Skype: owen-2345
* Stack Overflow: Use "camaleon" as tag to ask questions related to this CMS (don't forget to include cms version + rails version).
* Site: http://camaleon.tuzitio.com/

## Author
Owen Peredo Diaz

## License
http://camaleon.tuzitio.com/license.html

## Testing
* Init DB
```bash
RAILS_ENV=test bundle exec rake app:db:migrate
RAILS_ENV=test bundle exec rake app:db:test:prepare
```
* Run tests
```bash
bundle exec rspec
```

## Contributing
* Fork it.
* Create a branch (git checkout -b my_feature_branch)
* Commit your changes (git commit -am "Added a sweet feature")
* Push to the branch (git push origin my_feature_branch)
* Create a pull request from your branch into master (Please be sure to provide enough detail for us to understand what this change is doing)

## Version History

http://camaleon.tuzitio.com/version-history.html

Previous stable version (v1.x): https://github.com/owen2345/camaleon-cms/tree/version_1x

Camaleon CMS was originally released in July 2015 and tested previously with more than 20 projects by 6 months and on August 22, 2015 was published as a gem.
