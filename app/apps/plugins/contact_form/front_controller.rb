=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::ContactForm::FrontController < CamaleonCms::Apps::PluginsFrontController
  before_filter :append_view_paths

  def index
    # here your actions for frontend module
  end

  # here add your custom functions
  def save_form
    @form = current_site.contact_forms.find_by_id(params[:id])
    values = JSON.parse(@form.value).to_sym
    settings = JSON.parse(@form.settings).to_sym
    fields = params[:fields]
    attachments = []

    errors = []
    success = []

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

    if validate
      values[:fields].each do |f|
        cid = f[:cid].to_sym
        if f[:field_type] == 'file'
          res = upload_file(fields[cid], {maximum: 5.megabytes, folder: current_site.upload_directory("uploads")})
          if res[:error].present?
            errors << res[:error]
          else
            attachments << res['file']
          end
        end
      end

      new_settings = {"fields" => fields, "created_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s}.to_json
      @form_new = current_site.contact_forms.new(name: "response-#{Time.now}", description: @form.description, settings:fix_meta_value(new_settings), site_id: @form.site_id, parent_id: @form.id)

      if @form_new.save
        content = render_to_string partial: 'contact_form/submission',
                                   layout: false,
                                   locals: {
                                     file_attachments: attachments,
                                     fields: convert_form_values(
                                       values[:fields],
                                       fields
                                     )
                                   }
        # send mail
        sendmail(
          settings[:railscf_mail][:to], settings[:railscf_mail][:subject],
          content,
          settings[:railscf_mail][:to],
          attachments
        )
        success << settings[:railscf_message][:mail_sent_ok]
      else
        errors << settings[:railscf_message][:mail_sent_ng]
      end
    end

    if success.present?
      flash[:notice] = success.join('<br>')
    else
      flash[:error] = errors.join('<br>')
      flash[:values] = fields
    end

    redirect_to :back
  end

  private

  def append_view_paths
    append_view_path File.join($camaleon_engine_dir, 'app', 'apps', 'plugins', self_plugin_key, 'views')
  end

  def fix_meta_value(value)
    if value.is_a?(Array) || value.is_a?(Hash)
      value = value.to_json
    elsif value.is_a?(String)
      value = value.to_var
    end
    value
  end
end
