=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::VisitsCounter::VisitsCounterHelper

  # remove the widget with slug 'visits-counter'
  # delete the table of the plugin
  def visits_counter_on_destroy(plugin)
    @widget = @current_site.widgets.where({slug: 'visits-counter'}).first
    @widget.destroy
    ActiveRecord::Base.connection.execute('DROP TABLE plugins_visits_counters;');
  end

  # method which proceeds to create the plugin table and
  # create the widget with slug 'visits-counter'
  # when the plugin is active
  def visits_counter_on_active(plugin)

    # Check if there is a table with the method table_exists? (table_name)
    # if not there then proceeds to create the table
    unless ActiveRecord::Base.connection.table_exists? 'plugins_visits_counters'
      ActiveRecord::Base.connection.create_table :plugins_visits_counters do |t|
        t.integer :user_id, :post_id, :session_id, :site_id
        t.string :ip, :referrer, :remote_host
        t.text :data, :user_agent
        t.timestamps
      end
    end

    # Check if there is a column with any data type
    # with column_exists method? (table_name, column_name, data_type)
    # if there then proceeds to change the data type of the table with the method
    # t.change :column_name :data_type
    if ActiveRecord::Base.connection.column_exists?(:plugins_visits_counters, :session_id, :integer)
      ActiveRecord::Base.connection.change_table(:plugins_visits_counters) do |t|
        t.change :session_id, :text
      end
    end

    # get the first widget with slug 'visits-counter'
    @widget = @current_site.widgets.where({slug: 'visits-counter'}).first
    @site = current_site

    if !@widget.present?
      @widget = @site.widgets.new({name: 'Visits Counter', slug: 'visits-counter', description: 'Visits counter'})
      @widget.save
    end

  end

  # method which proceeds to destroy the widget with slug 'visits-counter'
  # when the plugin is inactive
  def visits_counter_on_inactive(plugin)
    @widget = @current_site.widgets.where({slug: 'visits-counter'}).first
    @widget.destroy
  end

  # Triggered for each request when the app is being accessed
  def visits_counter_app_before_load
    Site.class_eval do
      has_many :visits_counter, :class_name => "Plugins::VisitsCounter::Models::VisitsCounter", foreign_key: :site_id, dependent: :destroy
    end

    append_asset_libraries({"plugin_visits_counter"=> { css: [plugin_asset_path("visits_counter", "css/style.scss")] }})
  end

  # Triggered for each request when the frontend module was accessed
  def visits_counter_front_after
    if signin?
      current_site.visits_counter.create({session_id: get_session_id, site_id: current_site.id })
    else

      current_site.visits_counter.create({session_id: nil, site_id: current_site.id })
    end

  end

  # This will add link options for this plugin.
  def visits_counter_plugin_options(arg)
    arg[:links] << link_to(t('plugin.visits_counter.settings'), admin_plugins_visits_counter_settings_path)
  end
end