module CamaleonCms::EmailHelper
  include CamaleonCms::HooksHelper
  # send and email
  # email: email to
  # subject: Subject of the email
  # content: content of the email
  # from: email figured as from
  # attachs: array of files to be attached to the email
  # layout_name: path of the template to render
  # template_name: template name to render in template_path
  def send_email(email, subject='Notification', content='', from=nil, attachs=[], template_name = nil, layout_name = nil, extra_data = {})
    args = {attachs: attachs, extra_data: extra_data}
    args[:template_name] = template_name if template_name.present?
    args[:layout_name] = layout_name if layout_name.present?
    args[:from] = from if from.present?
    args[:content] = content if content.present?
    cama_send_email(email, subject, args)
  end

  # short method of send_email
  # args: content='', from=nil, attachs=[], url_base='', current_site, template_name, layout_name, extra_data, format, cc_to
  def cama_send_email(email_to, subject, args = {})
    args = {url_base: cama_root_url, current_site: current_site, subject: subject}.merge(args)
    args[:attachments] = args[:attachs] if args[:attachs].present?
    args[:current_site] = args[:current_site].id

    # run hook "email" to customize values
    hooks_run("email", args)
    CamaleonCms::HtmlMailer.sender(email_to, args[:subject], args).deliver_later
  end

  def send_user_confirm_email(user_to_confirm)
    user_to_confirm.send_confirm_email
    confirm_email_url = cama_admin_confirm_email_url({h: user_to_confirm.confirm_email_token})
    Rails.logger.debug "Camaleon CMS - Sending email verification to #{user_to_confirm}"
    extra_data = {:url => confirm_email_url, :fullname => user_to_confirm.fullname}
    send_email(user_to_confirm.email, t('camaleon_cms.admin.login.confirm.text'), '', nil, [], 'confirm_email', 'camaleon_cms/mailer', extra_data)
  end

  def send_password_reset_email(user_to_send)
    user_to_send.send_password_reset
    reset_url = cama_admin_forgot_url({h: user_to_send.password_reset_token})
    extra_data = {
        :url => reset_url,
        :fullname => user_to_send.fullname,
        :user => user_to_send
    }
    send_email(user_to_send.email, t('camaleon_cms.admin.login.message.subject_email'), '', nil, [], 'password_reset', 'camaleon_cms/mailer', extra_data)
  end

  # send email to the first administrator
  # args: same arguments than cama_send_email
  def cama_send_mail_to_admin(subject, args = {})
    cama_send_email(current_site.get_option('system_email', current_site.users.admin_scope.first.email), subject, args)
  end
end
