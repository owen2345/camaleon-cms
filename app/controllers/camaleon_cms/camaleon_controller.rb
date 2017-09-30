class CamaleonCms::CamaleonController < ApplicationController
  add_flash_types :warning
  add_flash_types :error
  add_flash_types :notice
  add_flash_types :info

  include CamaleonCms::CamaleonHelper
  include CamaleonCms::SessionHelper
  include CamaleonCms::SiteHelper
  include CamaleonCms::HtmlHelper
  include CamaleonCms::UserRolesHelper
  include CamaleonCms::ShortCodeHelper
  include CamaleonCms::PluginsHelper
  include CamaleonCms::ThemeHelper
  include CamaleonCms::HooksHelper
  include CamaleonCms::ContentHelper
  include CamaleonCms::CaptchaHelper
  include CamaleonCms::UploaderHelper
  include CamaleonCms::EmailHelper
  include Mobu::DetectMobile

  PluginRoutes.all_helpers.each{|h| include h.constantize }

  before_action :cama_site_check_existence, except: [:render_error, :captcha]
  before_action :cama_before_actions, except: [:render_error, :captcha]
  after_action :cama_after_actions, except: [:render_error, :captcha]
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  layout Proc.new { |controller| controller.request.xhr? ? false : 'default' }
  helper_method :current_user

  # show page error
  def render_error(status = 404, exception = nil, message = "")
    Rails.logger.debug "Camaleon CMS - 404 url: #{request.original_url rescue nil} ==> message: #{exception.message if exception.present?} ==> #{params[:error_msg]} ==> #{caller.inspect}"
    @message = "#{message} #{params[:error_msg] || (exception.present? ? "#{exception.message}<br><br>#{caller.inspect}" : "")}"
    @message = "" if Rails.env == "production"
    render "camaleon_cms/#{status}", :status => status
  end

  # generate captcha image
  def captcha
    image = cama_captcha_build(params[:len])
    send_data image.to_blob, :type => image.mime_type, :disposition => 'inline'
  end

  private
  def cama_before_actions
    # including all helpers (system, themes, plugins) for this site
    # PluginRoutes.enabled_apps(current_site, current_theme.slug).each{|plugin| plugin_load_helpers(plugin) }

    # initializing short codes
    shortcodes_init()

    # initializing before and after contents
    cama_html_helpers_init

    # initializing before and after contents
    cama_content_init

    @_hooks_skip = []
    # trigger all hooks before_load_app
    hooks_run("app_before_load")

    request.env.except!('HTTP_X_FORWARDED_HOST') if request.env['HTTP_X_FORWARDED_HOST'] # just drop the variable

    views_dir = "app/apps/"
    self.prepend_view_path(File.join($camaleon_engine_dir, views_dir).to_s)
    self.prepend_view_path(Rails.root.join(views_dir).to_s)

    CamaleonCms::PostDefault.current_user = cama_current_user
    CamaleonCms::PostDefault.current_site = current_site
  end

  # initialize ability for current user
  def current_ability
    @current_ability ||= CamaleonCms::Ability.new(cama_current_user, current_site)
  end

  def cama_after_actions
    # trigger all actions app after load
    hooks_run("app_after_load")
  end

  # redirect to sessions login form when the session was expired.
  def auth_session_error
    redirect_to cama_root_path
  end

  # check if current site exist, if not, this will be redirected to main domain
  # Also, check current site status
  def cama_site_check_existence()
    if !current_site.present?
      if Cama::Site.main_site.present?
        redirect_to Cama::Site.main_site.decorate.the_url
      else
        redirect_to cama_admin_installers_path
      end
    elsif (cama_current_user.present? && !cama_current_user.admin?) || !cama_current_user.present?
      # inactive page control
      if current_site.is_inactive?
        if request.original_url.to_s.match /\A#{current_site.the_url}admin(\/|\z)/
          if cama_current_user.present?
            cama_logout_user
            flash[:error] = ('Site is Inactive')
          end
        else
          p = current_site.posts.find_by_id(current_site.get_option('page_inactive')).try(:decorate)
          if p
            redirect_to(p.the_url) unless params == {"controller"=>"camaleon_cms/frontend", "action"=>"post", "slug"=>p.the_slug}
          else
            render html: 'This site was inactivated. Please contact to administrator.'
          end
        end
      end

      # maintenance page and IP's control
      if current_site.is_maintenance? && !current_site.get_option('maintenance_ips', '').split(',').include?(request.remote_ip)
        p = current_site.posts.find_by_id(current_site.get_option('page_maintenance')).try(:decorate)
        if p
          redirect_to(p.the_url) if params != {"controller"=>"camaleon_cms/frontend", "action"=>"post", "slug"=>p.the_slug}
        else
          render html: 'This site is in maintenance mode. Please contact to administrator.'
        end
      end
    end
  end

  def current_user
    cama_current_user
  end
end
