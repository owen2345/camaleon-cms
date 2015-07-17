class Plugins::{plugin_class}::AdminController < Apps::PluginsAdminController
  include Plugins::{plugin_class}::MainHelper
  def index
    # here your actions for admin panel
    # puts "--------------#{@plugin.inspect}"
  end

  def settings
    # this will render admin/settings.html.erb
  end

  def save_settings
    @plugin.set_field_values(params[:plugin_fields]) if params[:plugin_fields].present?

    # here save all your extra settings

    flash[:notice] = "Plugin updated."
    redirect_to action: :settings
  end

  # here add your custom functions

end