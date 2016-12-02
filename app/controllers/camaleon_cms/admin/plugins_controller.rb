class CamaleonCms::Admin::PluginsController < CamaleonCms::AdminController
  before_action :validate_role
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.plugins")
  def index
    PluginRoutes.reload
  end

  def toggle
    status = params[:status].to_bool
    if status == true # to inactivate
      plugin = plugin_uninstall(params[:id])
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('camaleon_cms.admin.message.was_inactivated')}"
    end

    unless status # to activate
      plugin = plugin_install(params[:id])
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('camaleon_cms.admin.message.was_activated')}"
    end
    PluginRoutes.reload
    redirect_to action: :index
  end

  # permit to upgrade a plugin for a new version
  def upgrade
    plugin = plugin_upgrade(params[:plugin_id])
    flash[:notice] = "Plugin \"#{plugin.title}\" #{t('camaleon_cms.admin.message.was_upgraded')}"
    PluginRoutes.reload
    redirect_to action: :index
  end

  def destroy
    plugin = plugin_destroy(params[:id])
    if plugin.error
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('camaleon_cms.admin.message.was_removed')}"
    else
      flash[:error] = "Plugin \"#{plugin.title}\" #{t('camaleon_cms.admin.message.can_not_be_removed')}"
    end
    redirect_to action: :index
  end

  private

  def validate_role
    authorize! :manage, :plugins
  end
end
