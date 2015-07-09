module Plugins::ShortcodesViewer::ShortcodesViewerHelper

  # here all actions before admin load
  def shortcodes_viewer_admin_before_load
    #admin_menu_append_menu_item("settings", {icon: "code", title: "Shortcodes", url: admin_plugins_shortcodes_viewer_index_path})
  end

  def shortcodes_viewer_plugin_options(arg)
    arg[:links] << link_to(t('plugin.shortcodes_viewer.settings'), admin_plugins_shortcodes_viewer_settings_path)
  end
end