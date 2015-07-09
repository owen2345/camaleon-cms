module Plugins::PostReorder::PostReorderHelper

  # get the plugin name with slug: 'post_reorder'
  def get_plugin
    plugin = current_site.plugins.find_by_slug("post_reorder")
  end

  def post_reorder_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def post_reorder_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def post_reorder_on_inactive(plugin)

  end

  # This adds a javascript to rearrange the elements of any type of content
  def post_reorder_on_list_post(values)

    plugin_meta = get_plugin.get_meta('_reorder_objects')

    if plugin_meta.present?
      plugin_meta[:post_type].each do |meta|
        if meta.to_i == values[:post_type].id.to_i
          append_asset_libraries({reorder: {js: [plugin_asset_path("post_reorder", "js/reorder.js")], css: [plugin_asset_path("post_reorder", "css/reorder.css")]}})
          content_append('<script>
                      run.push(function(){
                        $.fn.reorder({url: "'+admin_plugins_post_reorder_reorder_posts_path+'", table: "#posts-table-list"});
                      });
                    </script>')
        end
      end
    end
  end

  # This will add link options for this plugin.
  def post_reorder_plugin_options(arg)
    arg[:links] << link_to(t('plugin.post_reorder.settings'), admin_plugins_post_reorder_settings_path)
  end

end