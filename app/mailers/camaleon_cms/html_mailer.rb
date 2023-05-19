module CamaleonCms
  class HtmlMailer < ActionMailer::Base
    include CamaleonCms::SiteHelper
    include CamaleonCms::HooksHelper
    include CamaleonCms::PluginsHelper
    # include ApplicationHelper
    default from: 'Camaleon CMS <owenperedo@gmail.com>'
    after_action :set_delivery_options

    # content='', from=nil, attachs=[], url_base='', current_site, template_name, layout_name, extra_data, format, cc_to
    def sender(email, subject = 'Hello', data = {})
      data = data.to_sym
      if data[:current_site].present?
        data[:current_site] = CamaleonCms::Site.find(data[:current_site]).decorate if data[:current_site].is_a?(Integer)
      else
        data[:current_site] = CamaleonCms::Site.main_site.decorate
      end
      @current_site = data[:current_site]
      data = {
        cc_to: @current_site.get_option('email_cc', '').split(','),
        from: @current_site.get_option('email_from') || @current_site.get_option('email'),
        template_name: 'mailer',
        layout_name: 'camaleon_cms/mailer',
        format: 'html'
      }.merge(data)
      data[:cc_to] = [data[:cc_to]] if data[:cc_to].is_a?(String) || !data[:cc_to].present?

      mail_data = { to: email, subject: subject }
      if @current_site.get_option('mailer_enabled') == 1
        mail_data[:delivery_method] = :smtp
        mail_data[:delivery_method_options] = {
          user_name: @current_site.get_option('email_username'),
          password: @current_site.get_option('email_pass'),
          address: @current_site.get_option('email_server'),
          port: @current_site.get_option('email_port'),
          domain: begin
            @current_site.the_url.to_s.parse_domain
          rescue StandardError
            'localhost'
          end,
          authentication: 'plain',
          enable_starttls_auto: true
        }
      end
      mail_data[:cc] = data[:cc_to].clean_empty.join(',') if data[:cc_to].present?
      mail_data[:from] = data[:from] if data[:from].present?

      data[:mail_data] = mail_data
      hooks_run('email_late', data)

      @subject = subject
      @html = data[:content]
      @url_base = data[:url_base]
      @extra_data = data[:extra_data]

      views_dir = 'app/apps/'
      prepend_view_path(File.join($camaleon_engine_dir, views_dir).to_s)
      prepend_view_path(Rails.root.join(views_dir).to_s)

      theme = @current_site.get_theme
      if theme.settings && theme.settings['gem_mode']
        lookup_context.prefixes.prepend("themes/#{theme.slug}")
      else
        lookup_context.prefixes.prepend("themes/#{theme.slug}/views")
      end
      lookup_context.use_camaleon_partial_prefixes = true
      ((data[:files] || []) + (data[:attachments] || [])).each do |attach|
        if File.exist?(attach) && !File.directory?(attach)
          attachments[File.basename(attach).to_s] = File.open(attach, 'rb', &:read)
        else
          Rails.logger.error "Camaleon CMS - File attached in the email doesn't exist: #{attach}".cama_log_style(:red)
        end
      end

      layout = data[:layout_name].present? ? data[:layout_name] : false
      if data[:template_name].present? # render email with template
        if data[:format] == 'html'
          mail(mail_data) do |format|
            format.html do
              render data[:template_name], layout: layout
            end
          end
        end
        if data[:format] == 'txt'
          mail(mail_data) do |format|
            format.text do
              render data[:template_name], layout: layout
            end
          end
        end
      else # inline render content
        mail(mail_data) { |format| format.html { render inline: @html, layout: layout } } if data[:format] == 'html'
        mail(mail_data) { |format| format.text { render inline: @html, layout: layout } } if data[:format] == 'txt'
      end
      mail(mail_data) unless data[:format].present?
    end

    private

    # set default settings configured on admin panel
    def set_delivery_options
      return unless @current_site.get_option('mailer_enabled') == 1

      mail.perform_deliveries = true
    end
  end
end
