class ApplicationController < ActionController::Base
  include ApplicationHelper
  include SessionHelper
  include SiteHelper
  include HtmlHelper
  include UserRolesHelper
  include ShortCodeHelper
  include PluginsHelper
  include ThemeHelper
  include HooksHelper
  include ContentHelper
  include CaptchaHelper
  include UploaderHelper
  include Mobu::DetectMobile

  before_action :site_check_existence
  before_action :before_actions
  after_action :after_actions
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  layout Proc.new { |controller| controller.request.xhr? ? false : 'default' }

  # show page error
  def render_error(status = 404, exception = nil)
    Rails.logger.info "====================#{caller.inspect}"
    render :file => "public/#{status}.html", :status => status, :layout => false
  end

  # generate captcha image
  def captcha
    image = captcha_build(params[:len])
    send_data image.to_blob, :type => image.mime_type, :disposition => 'inline'
  end

  private
  def before_actions
    # including all helpers (system, themes, plugins) for this site
    PluginRoutes.enabled_apps(current_site).each{|plugin| plugin_load_helpers(plugin) }

    # set default cache directory for current site
    cache_store.cache_path = File.join(cache_store.cache_path.split("site-#{current_site.id}").first, "site-#{current_site.id}")
    # Rails.cache.write("#{current_site.id}-#{Time.now}", 1)


    # initializing short codes
    shortcodes_init()

    # initializing before and after contents
    html_helpers_init

    # initializing before and after contents
    content_init

    @_hooks_skip = []
    # trigger all hooks before_load_app
    hooks_run("app_before_load")

    request.env.except!('HTTP_X_FORWARDED_HOST') if request.env['HTTP_X_FORWARDED_HOST'] # just drop the variable

    # views path for plugins
    self.append_view_path(Rails.root.join("app", "apps", 'plugins'))
  end

  def after_actions
    # trigger all actions app after load
    hooks_run("app_after_load")
  end

  # redirect to sessions login form when the session was expired.
  def auth_session_error
    redirect_to root_path
  end

end
