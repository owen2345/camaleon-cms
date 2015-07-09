class Admin::PluginsController < AdminController
  before_action :validate_role
  def index
    PluginRoutes.reload
  end

  def toggle
    status = params[:status].to_bool
    if status == true # to inactivate
      plugin = plugin_uninstall(params[:id])
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_inactivated')}"
    end

    unless status # to activate
      plugin = plugin_install(params[:id])
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_activated')}"
    end
    PluginRoutes.reload
    redirect_to action: :index
  end

  def destroy
    plugin = plugin_destroy(params[:id])
    if plugin.error
      flash[:notice] = "Plugin \"#{plugin.title}\" #{t('admin.message.was_removed')}"
    else
      flash[:error] = "Plugin \"#{plugin.title}\" #{t('admin.message.can_not_be_removed')}"
    end
    redirect_to action: :index
  end

  private
  def validate_role
    authorize! :manager, :plugins
  end

end