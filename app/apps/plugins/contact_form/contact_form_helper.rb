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
          contact_new = current_site.contact_forms.new(sba_data.permit(:name, :slug, :count, :description, :value, :settings))
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
    admin_menu_append_menu_item("settings", {icon: "envelope-o", title: t('plugin.contact_form.contact_form'), url: admin_plugins_contact_form_admin_forms_path, datas: "data-intro='This plugin permit you to create you contact forms with desired fields and paste your short_code in any content.' data-position='right'"})
  end

  def contact_form_app_before_load
    shortcode_add('forms', plugin_view("forms_shorcode"), "This is a shortocode for contact form to permit you to put your contact form in any content. Sample: [forms slug='key-for-my-form']")
  end

  def contact_form_front_before_load

  end

  def perform_save_form(form, values, fields, settings, success, errors)
    attachments = []
    if validate_to_save_form(values, fields, settings, errors)
      values[:fields].each do |f|
        cid = f[:cid].to_sym
        if f[:field_type] == 'file'
          res = upload_file(fields[cid], {maximum: 5.megabytes, folder: 'contact_form'})
          if res[:error].present?
            errors << res[:error]
          else
            attachments << res['file']
          end
        end
      end

      new_settings = {"fields" => fields, "created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s}.to_json
      form_new = current_site.contact_forms.new(name: "response-#{Time.now}", description: form.description, settings: fix_meta_value(new_settings), site_id: form.site_id, parent_id: form.id)

      if form_new.save
        fields_data = convert_form_values(values[:fields], fields)
        content = render_to_string(partial: plugin_view('contact_form/email_content'), layout: false, locals: {file_attachments: attachments, fields: fields_data})
        cama_send_email(settings[:railscf_mail][:to], settings[:railscf_mail][:subject], {attachments: attachments, content: content, extra_data: {fields: fields_data}})
        success << settings[:railscf_message][:mail_sent_ok]
      else
        errors << settings[:railscf_message][:mail_sent_ng]
      end
    end
  end

  def validate_to_save_form(values, fields, settings, errors)
    validate = true
    values[:fields].each do |f|
      cid = f[:cid].to_sym
      label = f[:label].to_sym

      case f[:field_type].to_s
        when 'text', 'website', 'paragraph', 'textarea', 'email', 'radio', 'checkboxes', 'dropdown', 'file'
          if f[:required] && !fields[cid].present?
            errors << "#{label}: #{settings[:railscf_message][:invalid_required]}"
            validate = false
          end
          if f[:field_type].to_s == "email"
            if !fields[cid].match(/@/)
              errors << "#{label}: #{settings[:railscf_message][:invalid_email]}"
              validate = false
            end
          end
        when 'captcha'
          unless cama_captcha_verified?
            errors << "#{label}: #{settings[:railscf_message][:captcha_not_match]}"
            validate = false
          end
      end
    end
    validate
  end

  def fix_meta_value(value)
    if (value.is_a?(Array) || value.is_a?(Hash))
      value = value.to_json
    elsif value.is_a?(String)
      value = value.to_var
    end
    value
  end

end