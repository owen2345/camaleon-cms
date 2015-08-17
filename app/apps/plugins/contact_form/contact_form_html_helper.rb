=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::ContactForm::ContactFormHtmlHelper

  # This allows calls to methods plugin from html views
  def self.included(klass)
    klass.helper_method [:form_element_object, :form_element_bootstrap_object, :form_shortcode, :get_forms, :form_value_rescue]  rescue ""
  end

  # This returns the format of the plugin shortcode.
  def form_shortcode(slug)
    "[forms slug=#{slug}]"
  end

  # This returns all the answers on a form made from the frontend.
  def get_forms(id)
    current_site.contact_forms.where({parent_id: id})
  end

  def  form_value_rescue(form)
    JSON.parse(form.settings).to_sym rescue form.value
  end

  # form contact with css bootstrap
  def form_element_bootstrap_object(form, object)
    html = ""

    object.each do |ob|
      temp = "<div class='form-group'>
               <label>[label ci]</span></label>
               #{ '<p>[descr ci]</p>' if ob[:field_options][:description].present?}
               <div>[ci]</div>
            </div>"

      r = {field: ob, form: form, template: temp, custom_class: "form-control #{ob[:field_options][:field_class]}", custom_attrs: {id: ob[:cid] } }
      hooks_run("contact_form_item_render", r)
      ob = r[:field]
      ob[:custom_class] = r[:custom_class]
      ob[:custom_attrs] = r[:custom_attrs]
      field_options = ob[:field_options]
      for_name = ob[:label].to_s
      f_name = "fields[#{ob[:cid]}]"
      temp2 = ""

      case ob[:field_type].to_s
        when 'paragraph','textarea'
          temp2 = "<textarea #{ob[:custom_attrs].to_attr_format} name=\"#{f_name}\" maxlength=\"#{field_options[:maxlength]}\"  class=\"#{ob[:custom_class]}  \"></textarea>"
        when 'radio'
          temp2=  form_select_multiple_bootstrap(ob, ob[:label], ob[:field_type])
        when 'checkboxes'
          temp2=  form_select_multiple_bootstrap(ob, ob[:label], "checkbox")
        when 'text', 'website', 'email'
          class_type = ""

          class_type = "railscf-field-#{ob[:field_type]}" if ob[:field_type]=="website"
          class_type = "railscf-field-#{ob[:field_type]}" if ob[:field_type]=="email"

          temp2=  "<input #{ob[:custom_attrs].to_attr_format} type=\"#{ob[:field_type]}\" value=\"#{}\" name=\"#{f_name}\"  class=\"#{ob[:custom_class]} #{class_type}\">"
        when 'captcha'
          temp2= captcha_tag(5, {}, {class: "#{ob[:custom_class]} field-captcha required"}.merge(ob[:custom_attrs]))
        when 'file'
          class_type = "railscf-field-#{ob[:field_type]}" if ob[:field_type]=="website"
          temp2=  "<input multiple=\"multiple\" type=\"file\" value=\"#{}\" name=\"#{f_name}\" #{ob[:custom_attrs].to_attr_format} class=\"#{class_type} #{ob[:custom_class]}\">"
        when 'dropdown'
          temp2=  form_select_multiple_bootstrap(ob, ob[:label], "select")
        else
      end
      r[:template] = r[:template].sub('[label ci]', for_name).sub('[ci]', temp2)
      r[:template] = r[:template].sub('[descr ci]', field_options[:description] || "")
      html += r[:template]
    end
    html
  end

  def form_select_multiple_bootstrap(ob, title, type)

    options = ob[:field_options][:options]
    include_other_option = ob[:field_options][:include_other_option]
    other_input = ""

    f_name = "fields[#{ob[:cid]}]"
    f_label = ""
    html = ""
    if type=="radio" || type=="checkbox"
      other_input = (include_other_option)? "<div class=\"#{type} #{ob[:custom_class]}\"> <label for=\"#{ob[:cid]}\"><input id=\"#{ob[:cid]}-other\" type=\"#{type}\" name=\"#{title.downcase}[]\" class=\"\">Other <input type=\"text\" /></label></div>" : " "

    else
      html = "<select #{ob[:custom_attrs].to_attr_format} name=\"#{f_name}\" class=\"#{ob[:custom_class]}\">"
    end

    options.each do |op|
      if type == "radio" || type == "checkbox"
        html +=  "<div class=\"#{type} #{ob[:custom_class]}\">
                    <label for=\"#{ob[:cid]}\">
                      <input #{ob[:custom_attrs].to_attr_format} type=\"#{type}\" name=\"#{f_name}[]\" class=\"\" value=\"#{op[:label].downcase}\">
                      #{op[:label]}
                    </label>
                  </div>"
      else
        html +=  "<option value=\"#{op[:label].downcase.gsub(" ", "_")}\">#{op[:label]}</option>"
      end
    end

    if type=="radio" || type=="checkbox"
      html += other_input
    else
      html += " </select>"
    end

  end

  def form_post_email_content(op_body, op_fields, fields, file_attachments)
    @values = {}

    op_fields.each do |field|
      cid = field[:cid].to_sym
      label = field[:label]

      @values[label] = []

      if field[:field_type] == "file"
        @values[label] << fields[cid].original_filename  if fields[cid].present?
      elsif field[:field_type] == "captcha"
        @values[label] << session[:captcha]
      elsif field[:field_type] == "radio" || field[:field_type] == "checkboxes"
        @values[label] << fields[cid].join(",")  if fields[cid].present?
      else
        @values[label] << fields[cid]  if fields[cid].present?
      end

    end

    html = "<div class=\"data_body\"></div>"
    html += "<table style=\"width:100%; float:left\"><tbody><tr><td style=\"width:50%; float:left\">"

    @values.each do |ind, val|
      if val.to_s != "[]"
        html += "<div class=\"data_field\"><strong>"+ind + ":</strong>" + "#{val[0].to_s}" +"</div>"
      end
    end

    html += "</td><td style=\"width:48%; float:left; vertical-align: top;\">"

    file_attachments.each do |attachment|
      html += "<div class=\"data_link\"> <strong>Attachment:</strong> <a href=\"'#{attachment}'\">'#{File.basename(attachment)}'</a></div>"
    end

    html += "</td></tr></tbody></table>"
  end

end