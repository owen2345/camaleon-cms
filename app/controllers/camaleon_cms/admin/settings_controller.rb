class CamaleonCms::Admin::SettingsController < CamaleonCms::AdminController
  before_action :validate_role, except: [:theme, :save_theme]
  before_action :validate_role_theme, only: [:theme, :save_theme]
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.settings")

  def index
    redirect_to cama_admin_dashboard_path
  end

  def site
    return redirect_to cama_admin_settings_theme_path if params[:tab].present? && params[:tab] == 'theme'
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.general_site")
    @site = current_site
  end

  def site_saved
    @site = current_site
    cache_slug = @site.slug
    if @site.update(params.require(:site).permit!)
      @site.set_options(params[:options]) if params[:options].present?
      @site.set_metas(params[:metas]) if params[:metas].present?
      @site.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.settings.message.site_updated')
      args = {action: :site}
      args[:host], args[:port] = @site.get_domain.to_s.split(':') if cache_slug != @site.slug
      redirect_to(args)
    else
      render 'site'
    end
  end

  # list available languages
  def languages
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.languages")
  end

  # render the list of shortcodes
  def shortcodes
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.shortcodes")
  end

  # save language customizations
  def save_languages
    current_site.set_meta("languages_site", params[:lang])
    current_site.set_admin_language(params[:admin_language])
    I18n.locale = current_site.get_admin_language
    PluginRoutes.reload

    flash[:notice] =  t('camaleon_cms.admin.settings.message.language_updated', locale: current_site.get_admin_language)
    redirect_to action: :languages
  end

  def theme
    add_breadcrumb I18n.t("camaleon_cms.admin.settings.theme_setting", default: 'Theme Settings')
  end

  def save_theme
    current_theme.set_field_values(params[:theme_fields]) if params[:theme_fields].present?
    current_theme.set_options(params[:theme_option]) if params[:theme_option].present?
    current_theme.set_metas(params[:theme_meta]) if params[:theme_meta].present?
    current_theme.set_field_values(params[:field_options])
    hook_run(current_theme.settings, "on_theme_settings", current_theme)# permit to save extra/custom values by this hook
    flash[:notice] = t('camaleon_cms.admin.message.updated_success', default: 'Theme updated successfully')
    redirect_to action: :theme
  end

  # send email test
  def test_email
    begin
      CamaleonCms::HtmlMailer.sender(params[:email], 'Test', {content: 'Test content'}).deliver_now
      render nothing: true
    rescue => e
      render inline: e.message, status: 502
    end
  end

  private

  def validate_role
    authorize! :manage, :settings
  end

  def validate_role_theme
    authorize! :manage, :theme_settings
  end
end
