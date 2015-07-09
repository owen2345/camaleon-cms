class HtmlMailer < ActionMailer::Base
  #include ApplicationHelper
  default from: "WPRails <info@wprails.com>"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.password_reset.subject
  #
  def sender(email, subject='Hello', content='', from=nil, attachs=[], url_base='', current_site, template_path, template_name)
    from = "WPRails <info@wprails.com>" if from.nil?
    @subject = subject
    @html = content
    @url_base = url_base
    @current_site = current_site

    if attachs.present?
      attachs.each do |attach|
        attachments["#{File.basename(attach)}"] = File.open(attach, 'rb'){|f| f.read}
      end
    end


    #begin
      if email.present?
        mail to: email, subject: subject, from: from, template_path: template_path, template_name: template_name.to_s

      else
        Rails.logger.debug "Error: Email no presente: \"#{subject}\""
      end
    #rescue => e
    #  Rails.logger.debug "Error al envio de email para #{email} \"#{subject}\": #{e.inspect}"
    #end


  end


end
