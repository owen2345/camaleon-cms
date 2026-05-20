module CamaleonCms
  class CamaleonController < ApplicationController
    add_flash_types :warning
    add_flash_types :error
    add_flash_types :notice
    add_flash_types :info

    include CamaleonCms::SessionRuntimeConcern
    include CamaleonCms::RequestContextConcern
    include CamaleonCms::HookLifecycleConcern
    include CamaleonCms::RuntimeShortcodeThemeConcern
    include CamaleonCms::RuntimeHtmlContentConcern
    include CamaleonCms::RuntimeAdminMenuConcern
    include CamaleonCms::RuntimeCaptchaImageConcern
    include CamaleonCms::RuntimeUploaderConcern
    include Mobu::DetectMobile
    delegate :tag, :content_tag, :safe_join, :image_tag, :link_to, :sanitize, to: :helpers

    before_action :cama_site_check_existence, except: [:captcha]
    before_action :cama_before_actions, except: [:captcha]
    after_action :cama_after_actions, except: [:captcha]
    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    # Skip forgery check on .js files located in /assets/ to avoid CORS errors
    # caused by requests for non-existent files.
    protect_from_forgery with: :exception, unless: -> { request.fullpath.match(%r{\A/assets/.*\.js\z}) }
    layout proc { |controller| controller.request.xhr? ? false : 'default' }
    helper_method :current_user

    # show page error
    def render_error(status = 404, exception = nil, message = '')
      error_msg = params[:error_msg]
      Rails.logger.debug do
        original_url = begin
          request.original_url
        rescue StandardError
          nil
        end
        'Camaleon CMS - 404 url: ' \
          "#{original_url} ==> message: #{exception&.message} ==> #{error_msg} ==> #{caller.inspect}"
      end

      @message = if Rails.env.production?
                   ''
                 else
                   "#{message} " \
                     "#{error_msg || (exception.present? ? "#{exception.message}<br><br>#{caller.inspect}" : '')}"
                 end

      respond_to do |format|
        format.html { render "camaleon_cms/#{status}", status: status }
        format.any { head status }
      end
    end

    # generate captcha image
    def captcha
      image = cama_captcha_build(params[:len])
      send_data image.to_blob, type: MiniMime.lookup_by_extension(image.type).content_type, disposition: 'inline'
    end

    private

    def cama_before_actions
      # including all helpers (system, themes, plugins) for this site
      # PluginRoutes.enabled_apps(current_site, current_theme.slug).each{|plugin| plugin_load_helpers(plugin) }

      # initializing short codes
      shortcodes_init

      # initializing before and after contents
      cama_html_helpers_init

      # initializing before and after contents
      cama_content_init

      initialize_hook_skip_list
      run_app_before_load_hooks
      configure_runtime_request_context
    end

    # initialize ability for current user
    def current_ability
      @current_ability ||= CamaleonCms::Ability.new(cama_current_user, current_site)
    end

    def cama_after_actions
      run_app_after_load_hooks
    end
  end
end
