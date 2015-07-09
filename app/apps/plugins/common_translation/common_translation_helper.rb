module Plugins::CommonTranslation::CommonTranslationHelper


  # here all actions on plugin destroying
  # plugin: plugin model
  def common_translation_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def common_translation_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def common_translation_on_inactive(plugin)

  end

  def common_translation_on_translation(args)
    begin
      @_plugin_custom_translation_vals ||= current_site.plugins.where(slug: "common_translation").first.get_meta("custom_translations")
      c_trans = @_plugin_custom_translation_vals[args[:locale]][args[:key].to_sym]
      if c_trans
        args[:translation] = c_trans
        args[:flag] = true
      end
    rescue Exception => e
    end
  end

  def common_translation_plugin_options(arg)
    arg[:links] << link_to(t('plugin.common_translation.settings'), admin_plugins_common_translation_index_path)
  end
end