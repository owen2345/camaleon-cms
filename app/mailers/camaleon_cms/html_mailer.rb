=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::HtmlMailer < ActionMailer::Base
  include CamaleonCms::SiteHelper
  include CamaleonCms::HooksHelper
  include CamaleonCms::PluginsHelper
  #include ApplicationHelper
  default from: "Camaleon CMS <owenperedo@gmail.com>"
  after_action :set_delivery_options

  # content='', from=nil, attachs=[], url_base='', current_site, template_name, layout_name, extra_data, format, cc_to
  def sender(email, subject='Hello', data = {})
    data = data.to_sym
    data[:current_site] = CamaleonCms::Site.main_site.decorate unless data[:current_site].present?
    data[:current_site] = CamaleonCms::Site.find(data[:current_site]).decorate if data[:current_site].is_a?(Integer)
    current_site = @current_site = data[:current_site]
    data = {cc_to: current_site.get_option("email_cc", '').split(','), from: current_site.get_option("email_from") || current_site.get_option("email"), template_name: 'mailer', layout_name: 'camaleon_cms/mailer', format: 'html'}.merge(data)
    @subject = subject
    @html = data[:content]
    @url_base = data[:url_base]
    @extra_data = data[:extra_data]
    data[:cc_to] = [data[:cc_to]] if data[:cc_to].is_a?(String) || !data[:cc_to].present?

    mail_data = {to: email, subject: subject}
    if current_site.get_option("mailer_enabled") == 1
      mail_data[:delivery_method] = :smtp
      mail_data[:delivery_method_options] = {user_name: current_site.get_option("email_username"),
                                             password: current_site.get_option("email_pass"),
                                             address: current_site.get_option("email_server"),
                                             port: current_site.get_option("email_port"),
                                             domain: (current_site.the_url.to_s.parse_domain rescue "localhost"),
                                             authentication: "plain",
                                             enable_starttls_auto: true
      }
    end
    mail_data[:cc] = data[:cc_to].clean_empty.join(",") if data[:cc_to].present?
    mail_data[:from] = data[:from] if data[:from].present?

    views_dir = "app/apps/"
    self.prepend_view_path(File.join($camaleon_engine_dir, views_dir).to_s)
    self.prepend_view_path(Rails.root.join(views_dir).to_s)

    theme = current_site.get_theme
    lookup_context.prefixes.prepend("themes/#{theme.slug}") if theme.settings["gem_mode"]
    lookup_context.prefixes.prepend("themes/#{theme.slug}/views") unless theme.settings["gem_mode"]
    lookup_context.use_camaleon_partial_prefixes = true
    (data[:files] || data[:attachments] || []).each{ |attach|
      if File.exist?(attach) && !File.directory?(attach)
        attachments["#{File.basename(attach)}"] = File.open(attach, 'rb') { |f| f.read }
      else
        Rails.logger.error "File not attached in the mail: #{attach}"
      end
    }

    layout = data[:layout_name].present? ? data[:layout_name] : false
    if data[:template_name].present? # render email with template
      mail(mail_data) { |format| format.html { render data[:template_name], layout: layout } } if data[:format] == "html"
      mail(mail_data) { |format| format.text { render data[:template_name], layout: layout } } if data[:format] == "txt"
    else # inline render content
      mail(mail_data) { |format| format.html { render inline: @html, layout: layout } } if data[:format] == "html"
      mail(mail_data) { |format| format.text { render inline: @html, layout: layout } } if data[:format] == "txt"
    end
    mail(mail_data) unless data[:format].present?
  end

  private
  # set default settings configured on admin panel
  def set_delivery_options
    if @current_site.get_option("mailer_enabled") == 1
      mail.perform_deliveries = true
    end
  end
end
