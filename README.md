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
  gem 'camaleon_cms', '0.2.1' # if you want the previous stable version
  gem 'camaleon_cms' # if you want the latest version (1.0)
  ```
* Install the gem

  ```
  bundle install # bundle update if you have previous version installed
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

# Migrating from 0.2.x or earlier?

1. Install camaleon as a gem as stated above or run `bundle update 'camaleon_cms'`
1. Remove `lib/Gemfile_camaleon`

  ```bash
  rm lib/Gemfile_camaleon
  ```
1. Install gems

  ```bash
  bundle install
  ```
1. Update `lib/plugin_routes.rb`

  ```bash
  rails generate camaleon_cms:install
  ```
1. Start/restart Rails

  ```bash
  rails server
  ```

# Camaleon CMS (It adapts to your needs)

Camaleon CMS is a dynamic and advanced content management system based on Ruby on Rails 4 and Ruby 1.9.3+. This CMS is an alternative to wordpress for Ruby on Rails developers to manage advanced contents easily.  
Camaleon CMS is a flexible manager where you can build your custom content structure without coding anything by custom fields and custom contents type.

To download or publish themes go to themes store:
http://camaleon.tuzitio.com/store/themes

To download or publish plugins go to plugins store:
http://camaleon.tuzitio.com/store/plugins

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
* [Camaleon Server (current version)](http://camaleon.tuzitio.com/plugins/demo_manage/)
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
* Documentation and Videos
* Create more basic plugins

## Contributing
* Fork it.
* Create a branch (git checkout -b my_feature_branch)
* Commit your changes (git commit -am "Added a sweet feature")
* Push to the branch (git push origin my_feature_branch)
* Create a pull request from your branch into master (Please be sure to provide enough detail for us to cipher what this change is doing)

Visit the web site for more information: http://camaleon.tuzitio.com/

## Version History
### 1.0
* new template for admin panel
* gem plugin generator
  console:
  rails g camaleon_cms:gem_plugin post_reorder
  bundle install
  visit frontend: http://localhost:3000/plugins/post_reorder/index
  visit backend: http://localhost:3000/admin/plugins/post_reorder/index
  Check here to publish your gem http://guides.rubygems.org/publishing/
* gem plugin support added
* changed post structure to improve sql query
* added custom field orderer
  sort_by_field(...)
  sample: Site.first.posts.sort_by_field("untitled-field-attributes", "desc")
* Added layouts selector like template selector
* Added support custom fields for menu items
  Add any custom fields into menus and it will appear for each menu item (ideal to add icons or custom text for each menu)
* I18n(..) for javascript
  You don't need to print your translations in html, put your translations in:
  Sample:
  ``en:
    admin:
      js:
        button
          my_text: "asasa"

  I18n("button.my_text")``
* hooks for email
* shortcodes support for content editor
* hook "user_update_more_actions" to add more action in user profile
* added slug render support for categories, post_types, post_tags. Check doc.
* fixed the default view "post.html.erb" into "single.html.erb". Check doc.
* added the_field!(..) and get_field!(..) method in custom fields to manage empty values. Check doc.
* added a control for logged users the_edit_link
* added the_author method for posts
* added the_categories method for sites
* added cama_edit_link(...) to create common edit links anywhere, this verify if current visitor was logged in
* added default shortcodes: load_libreries (load custom libraries), asset (render an url or image tag with the url), post_url (render an url for a post by id or slug)
* fixed shortcode to support shortcodes with almost the same name. sample: [asset] [asset_path]
* added method cama_strip_shortcodes(..) to strip all shortcodes
* added get_fields(..) to get multiple values of a custom field
* added filters for categories (.no_empty, .empty)
* Added method for post: set_summary(..)
* Added method for post: set_thumb(..)
* Added method for post: increment_visits!
* Added method for post: total_visits
* Added method for post: total_comments
* Added extra support values for method add_post(..) in post_type object
* Added shortcode "post_url"
  Permit to generate the url of a post (add path='' to generate the path and not the full url,
    add id='123' to use the POST ID,
    add key='my_slug' to use the POST SLUG,
    add link='true' to generate the full link,
    add title='my title' text of the link (default post title),
    add target='_blank' to open the link in a new window this is valid only if link is present),
  sample: [post_url id='122' link=true target='_blank']
* Added shortcode "asset"
  Permit to generate an asset url (
    add file='' asset file path,
    add as_path='true' to generate only the path and not the full url,
    add class='my_class' to setup image class,
    add style='height: 100px; width: 200px;...' to setup image style,
    add image='true' to generate the image tag with this url),
  sample: <img src=\"[asset as_path='true' file='themes/my_theme/assets/img/signature.png']\" /> or [asset image='true' file='themes/my_theme/assets/img/signature.png' style='height: 50px;']
* Added shortcode "custom_field"
  Permit you to include your custom fields in anywhere.
  key: slug or key of the custom_field
  attrs: custom html attributes
  render: (true) enable to render the custom field as html. (Sample text_field: <span>my_field_value</span>)
  post_slug: (Optional, default current post) slug or key of a Post.
  Sample1: [custom_field key='subtitle']
  Sample2: [custom_field key='subtitle' post_slug='contact' render=true attrs='style=\"width: 50px;\"'] // return the custom field of page with slug = contact

### 0.2.1
* fixed sprockets problem: https://github.com/owen2345/camaleon-cms/issues/53

### 0.2.0
* datetimepicker
* Plugin files separated in two files, please update with: rails g camaleon_cms:install //and replace plugin_routes.rb
* Added the edit url for post/posttypes/categories
* Added plugin upgrade support
* Added confirm for disable/enable a plugin

### 0.1.10
* Fix rufus initializer
* Changed plugins documentation link
* Fixed current locale for editors
* Rails 4.1 support added

### 0.1.6
* Added Italian language support
