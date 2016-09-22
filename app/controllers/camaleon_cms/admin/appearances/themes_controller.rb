class CamaleonCms::Admin::Appearances::ThemesController < CamaleonCms::AdminController
  before_action :check_theme_permission
  # list themes or update a theme status
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.appearance")
  def index
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.themes")
    PluginRoutes.reload
    authorize! :manage, :themes
    if params[:set].present?
      site_install_theme(params[:set])
      flash.now[:notice] = t('camaleon_cms.admin.themes.message.updated')
      redirect_to action: :index
    end
  end

  def load_data
    file = Rails.root.join("app", "apps", 'themes', current_site.get_theme_slug, 'data.json')
    @messages = load_file_content_to_db(file, {post_types: 1, clear_post_type: 1, nav_menus: 1, clear_nav_menus: 1, slider_basic: 1, clear_slider_basic: 1, theme_import: 1})
  end

  def preview
    render layout: false
  end

  private
  def check_theme_permission
    authorize! :manage, :themes
  end
end
