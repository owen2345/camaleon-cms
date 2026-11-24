module CamaleonCms
  module Admin
    module Appearances
      class ThemesController < CamaleonCms::AdminController
        before_action :check_theme_permission
        # list themes or update a theme status
        add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.appearance')
        def index
          add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.themes')
          authorize! :manage, :themes
          return if params[:set].blank?

          if PluginRoutes.theme_info(params[:set]).blank?
            flash[:error] = t('camaleon_cms.admin.themes.message.not_installed', default: 'The theme is not installed.')
            return redirect_to action: :index
          end

          site_install_theme(params[:set])
          flash[:notice] = t('camaleon_cms.admin.themes.message.updated')
          redirect_to action: :index
        rescue CamaleonCms::RouteDrawError => e
          # The switch is a GET request, and AdminController raises this error again for a GET request.
          # The list has no draw of the routes, so the redirect leads to a page that works.
          log_route_draw_error(e)
          # A failed trial in the savepoint of the switch rolls the switch back, so the site keeps its old
          # theme. The draw after the commit of the switch runs a trial again. A change outside the switch can
          # fail that trial: the theme then stays switched, and the message says that Camaleon kept the routes.
          flash[:error] = route_draw_error_message(e, as_text: false)
          redirect_to action: :index
        rescue CamaleonCms::RouteReloadLock::WaitTimeout
          # Another theme switch held the lock of the route reload, and this switch wrote nothing.
          flash[:error] = t('camaleon_cms.admin.themes.message.another_switch_runs',
                            default: 'Another theme switch runs now, so Camaleon did not switch the theme. Try again.')
          redirect_to action: :index
        end

        def load_data
          file = Rails.root.join('app', 'apps', 'themes', current_site.get_theme_slug, 'data.json')
          @messages = load_file_content_to_db(
            file,
            {
              post_types: 1, clear_post_type: 1, nav_menus: 1, clear_nav_menus: 1, slider_basic: 1,
              clear_slider_basic: 1, theme_import: 1
            }
          )
        end

        def preview
          render layout: false
        end

        private

        def check_theme_permission
          authorize! :manage, :themes
        end
      end
    end
  end
end
