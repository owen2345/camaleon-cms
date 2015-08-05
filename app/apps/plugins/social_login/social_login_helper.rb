=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::SocialLogin::SocialLoginHelper

  # get the plugin name with slug: 'social_login'
  def get_plugin_social
    plugin = current_site.plugins.where(slug: "social_login").first
  end

  # here all actions on plugin destroying
  # plugin: plugin model
  def social_login_on_destroy(plugin)

  end

  # method which proceeds to create the plugin table
  # add add column_name with method  add_column(table_name, column_name, data_type)
  def social_login_on_active(plugin)

    # Check if there is a table with the method table_exists? (table_name)
    # if not there then proceeds to create the table
    unless ActiveRecord::Base.connection.table_exists? 'plugins_social_logins'
      ActiveRecord::Base.connection.create_table :plugins_social_logins do |t|
        t.integer :user_id, :site_id
        t.string :provider, :uid
        t.text :content
        t.timestamps
      end
    end

    # Check if there is a column with any data type
    # with column_exists method? (table_name, column_name, data_type)
    # if not there then proceeds to add column to the table with the method
    # add_column(table_name, column_name, data_type)
    if !ActiveRecord::Base.connection.column_exists?(:plugins_social_logins, :site_id, :integer)
      ActiveRecord::Base.connection.add_column("plugins_social_logins", "site_id", "integer")
    end

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def social_login_on_inactive(plugin)

  end

  # This will add html code to access social networking system
  def social_login_session_before
    if params[:controller] == "admin/sessions" && (params[:action] == "login" || params[:action] == "login_post")
      @user = User.new
      content_prepend(render_to_string partial: plugin_view("social_login", "admin/login"))
    end
  end

  # Triggered for each request when the app is being accessed
  def social_login_app_before_load
    Site.class_eval do
      has_many :social_login, :class_name => "Plugins::SocialLogin::Models::SocialLogin", foreign_key: :site_id, dependent: :destroy
    end
  end

  # This will add html code to record the links of social networks in the database
  def social_login_user_form(args)
    @site = current_site
    args[:html] = render partial: plugin_view("social_login", "admin/social_user"), locals: {site: @site }
  end

  # This will add link options for this plugin.
  def social_login_plugin_options(arg)
    arg[:links] << link_to(t('plugin.social_login.settings'), admin_plugins_social_login_settings_path)
  end
end