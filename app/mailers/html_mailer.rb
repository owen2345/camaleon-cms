=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class HtmlMailer < ActionMailer::Base
  #include ApplicationHelper
  default from: "Camaleon CMS <owenperedo@gmail.com>"
  after_action :set_delivery_options

  def sender(email, subject='Hello', content='', from=nil, attachs=[], url_base='', current_site, template_name, layout_name)
    @subject = subject
    @html = content
    @url_base = url_base
    @current_site = current_site

    if attachs.present?
      attachs.each{|attach| attachments["#{File.basename(attach)}"] = File.open(attach, 'rb'){|f| f.read} }
    end

    mail_data = {to: email, subject: subject}
    mail_data[:from] = from if from.present?

    if current_site.get_option("mailer_enabled") == 1
      mail_data[:from] = current_site.get_option("email_from")
      mail_data[:cc] = current_site.get_option("email_cc")
      mail_data[:delivery_method] = :smtp
      mail_data[:delivery_method_options] = { user_name: current_site.get_option("email_username"),
                                              password: current_site.get_option("email_pass"),
                                              address: current_site.get_option("email_server"),
                                              port: current_site.get_option("email_port"),
                                              domain: "localhost",
                                              authentication: "plain",
                                              enable_starttls_auto: true
                                            }
    end

    views_dir = "app/apps/themes/#{current_site.get_theme.slug}/views"
    self.prepend_view_path(File.join($camaleon_engine_dir, views_dir).to_s)
    self.prepend_view_path(Rails.root.join(views_dir).to_s)

    # puts "&&&&&&&&&&&&&&&#{lookup_context.inspect}-----#{template_name}==#{layout_name}"
    mail(mail_data){|format| format.html { render template_name, layout: layout_name } }
  end

  private
  # set default settings configured on admin panel
  def set_delivery_options
    if @current_site.get_option("mailer_enabled") == 1
      mail.perform_deliveries = true
    end
  end
end
