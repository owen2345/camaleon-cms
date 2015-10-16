=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::CamaleonController < ApplicationController
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
  include Mobu::DetectMobile

  prepend_before_action :cama_load_custom_models
  before_action :cama_site_check_existence, except: [:render_error, :captcha]
  before_action :cama_before_actions, except: [:render_error, :captcha]
  after_action :cama_after_actions, except: [:render_error, :captcha]
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
    image = cama_captcha_build(params[:len])
    send_data image.to_blob, :type => image.mime_type, :disposition => 'inline'
  end

  private
  def cama_before_actions
    # including all helpers (system, themes, plugins) for this site
    PluginRoutes.enabled_apps(current_site, current_theme.slug).each{|plugin| plugin_load_helpers(plugin) }

    # set default cache directory for current site
    cache_store.cache_path = File.join(cache_store.cache_path.split("site-#{current_site.id}").first, "site-#{current_site.id}")
    # Rails.cache.write("#{current_site.id}-#{Time.now}", 1)

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
  end

  # initialize ability for current user
  def current_ability
    @current_ability ||= CamaleonCms::Ability.new(current_user, current_site)
  end

  def cama_after_actions
    # trigger all actions app after load
    hooks_run("app_after_load")
  end

  # redirect to sessions login form when the session was expired.
  def auth_session_error
    redirect_to root_path
  end

  # include CamaleonCms::all custom models created by installed plugins or themes for current site
  def cama_load_custom_models
    if current_site.present?
      site_load_custom_models(current_site)
    end
  end

  # add custom views of camaleon
  def camaleon_add_front_view_paths
    # self.prepend_view_path(File.join($camaleon_engine_dir, "app", "views", "camaleon_cms", 'default_theme'))
    # self.prepend_view_path(Rails.root.join("app", "views", "camaleon_cms", 'default_theme'))
    if current_site.present?
      if current_theme.present?
        # lookup_context.prefixes.prepend("camaleon_cms/default_theme")
        lookup_context.prefixes.prepend("themes/#{current_theme.slug}") if current_theme.settings["gem_mode"]
        lookup_context.prefixes.prepend("themes/#{current_theme.slug}/views") unless current_theme.settings["gem_mode"]
        lookup_context.prefixes.prepend("themes/#{current_site.id}/views")
        views_dir = "app/apps/"
        self.prepend_view_path(File.join($camaleon_engine_dir, views_dir).to_s)
        self.prepend_view_path(Rails.root.join(views_dir).to_s)
      end
    end
  end
end
