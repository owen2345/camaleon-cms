# frozen_string_literal: true

# Gives the app an enabled plugin whose route file raises an error, as PluginRoutes.load reads it. A
# trial draw of the routes then fails. A draw of the app routes with no trial loses the routes.
module BrokenRouteFileHelper
  def break_the_routes(text = "raise ArgumentError, 'broken plugin routes'")
    @broken_plugin_dir = Dir.mktmpdir('broken_routes_plugin')
    FileUtils.mkdir_p(File.join(@broken_plugin_dir, 'config'))
    File.write(File.join(@broken_plugin_dir, 'config', 'routes_main.txt'), text)
    broken = { 'key' => 'broken_routes', 'path' => @broken_plugin_dir }
    allow(PluginRoutes).to(receive(:all_enabled_plugins).and_wrap_original { |original| original.call + [broken] })
  end

  # Removes the route file, and draws the routes again when a draw lost them.
  def repair_the_routes
    return unless @broken_plugin_dir

    FileUtils.rm_rf(@broken_plugin_dir)
    allow(PluginRoutes).to receive(:all_enabled_plugins).and_call_original
    Rails.application.reload_routes! unless app_route_names.include?(:cama_admin_dashboard)
  end

  def app_route_names
    Rails.application.routes.named_routes.names
  end
end

RSpec.configure do |config|
  config.include BrokenRouteFileHelper
  config.after { repair_the_routes }
end
