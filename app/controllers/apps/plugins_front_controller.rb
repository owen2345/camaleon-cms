class Apps::PluginsFrontController < FrontendController
  before_action :init_plugin

  private
  def init_plugin
    plugin_name = params[:controller].split("/")[1]
    @plugin = current_site.plugins.where(slug: plugin_name).first
    return render_error(404) unless @plugin.active?
    lookup_context.prefixes.prepend(params[:controller].sub("plugins/#{plugin_name}", "#{plugin_name}/views"))
    self.append_view_path(Rails.root.join("app", 'apps', "plugins"))
  end

end