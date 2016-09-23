class CamaleonCms::Apps::PluginsAdminController < CamaleonCms::AdminController
  before_action :init_plugin

  private

  def init_plugin
    plugin_name = params[:controller].split("/")[1]
    @plugin = current_site.plugins.where(slug: plugin_name).first_or_create
    unless @plugin.active?
      flash[:error] = t("camaleon_cms.plugin_not_installed", default: "This plugin is not installed, please contact to the administrator.")
      redirect_to cama_root_url
      return
    end
    if !@plugin.settings["gem_mode"].present?
      lookup_context.prefixes.delete_if{|t| t =~ /plugins\/(.*)\/views/i }
      lookup_context.prefixes.prepend(params[:controller].sub("plugins/#{plugin_name}", "plugins/#{plugin_name}/views"))
    end
  end
end
