module CamaleonCms::EmailHelper

  # send and email
  # email: email to
  # subject: Subject of the email
  # content: content of the email
  # from: email figured as from
  # attachs: array of files to be attached to the email
  # layout_name: path of the template to render
  # template_name: template name to render in template_path
  def send_email(email, subject='Tiene una notificacion', content='', from=nil, attachs=[], template_name = 'mailer', layout_name = 'camaleon_cms/mailer', extra_data = {})
    # Thread.abort_on_exception=true
    Thread.new do
      HtmlMailer.sender(email, subject, content, from, attachs, cama_root_url, current_site, template_name, layout_name, extra_data).deliver_now
      ActiveRecord::Base.connection.close
    end
  end

  def send_user_confirm_email(user_to_confirm)
    Rails.logger.info "Sending email verification to #{user_to_confirm}"
    extra_data = {:url => 'http://verify.email.com', :fullname => user_to_confirm.fullname}
    send_email(user_to_confirm.email, t('camaleon_cms.admin.login.confirm.text'), '', nil, [], 'confirm_email', 'camaleon_cms/mailer', extra_data)
  end

end