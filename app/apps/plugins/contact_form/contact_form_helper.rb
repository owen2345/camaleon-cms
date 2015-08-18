=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::ContactForm::ContactFormHelper
  def self.included(klass)
    klass.helper_method :get_plugin_form rescue ""
  end

  def get_plugin_form
    plugin = current_plugin
  end

  def contact_form_on_export(args)
    args[:obj][:plugins][self_plugin_key] = JSON.parse(current_site.contact_forms.to_json(:include => [:responses]))
  end

  def contact_form_on_import(args)
    plugins = args[:data][:plugins]
    if plugins[self_plugin_key.to_sym].present?
      plugins[self_plugin_key.to_sym].each do |contact|
        unless current_site.contact_forms.where(slug: contact[:slug]).first.present?
          sba_data = ActionController::Parameters.new(contact)
          contact_new = current_site.slider_basics.new(sba_data.permit(:name, :slug, :count, :description, :value, :settings))
          if contact_new.save!
            if contact[:get_field_groups] # save group fields
              save_field_group(contact_new, contact[:get_field_groups])
            end
            save_field_values(contact_new, contact[:field_values])

            if contact[:responses].present? # saving responses for this contact
              contact[:responses].each do |response|
                sba_data = ActionController::Parameters.new(response)
                contact_new.responses.create!(sba_data.permit(:name, :slug, :count, :description, :value, :settings))
              end
            end
            args[:messages] << "Saved Plugin Contact Form: #{contact_new.name}"
          end
        end
      end
    end
  end

  # here all actions on plugin destroying
  # plugin: plugin model
  def contact_form_on_destroy(plugin)
    ActiveRecord::Base.connection.execute('DROP TABLE plugins_contact_forms;');
  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def contact_form_on_active(plugin)
    unless ActiveRecord::Base.connection.table_exists? 'plugins_contact_forms'

      ActiveRecord::Base.connection.create_table :plugins_contact_forms do |t|
        t.integer :site_id, :count, :parent_id
        t.string :name, :slug
        t.text :description, :value, :settings
        t.timestamps
      end
    end
  end

  # here all actions on going to inactive
  # plugin: plugin model
  def contact_form_on_inactive(plugin)

  end

  def contact_form_admin_before_load
    admin_menu_append_menu_item("settings", {icon: "envelope-o", title: t('plugin.contact_form.contact_form'), url:  admin_plugins_contact_form_admin_forms_path})
  end

  def contact_form_app_before_load
    Site.class_eval do
      has_many :contact_forms, :class_name => "Plugins::ContactForm::Models::ContactForm", foreign_key: :site_id, dependent: :destroy
    end

  end

  def contact_form_front_before_load
    shortcode_add('forms',  plugin_view("contact_form", "forms_shorcode"))
    append_asset_libraries({"plugin_contact_form"=> { css: [plugin_asset_path("contact_form", "css/front/railsform")] }})
  end
end