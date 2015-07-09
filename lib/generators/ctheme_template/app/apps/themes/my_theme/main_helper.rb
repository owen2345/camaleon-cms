module Themes::{theme_class}::MainHelper
  def self.included(klass)
    #klass.helper_method [:my_helper_method] rescue "" # here your methods accessible from views
  end

  def {theme_key}_settings(theme)
    # here your code on save settings for current site, by default params[:theme_fields] is auto saved into theme
    # Also, you can save your extra values added in admin/settings.html.erb
    # sample: theme.set_meta("my_key", params[:my_value])
  end

  def {theme_key}_on_install_theme(theme)
    unless theme.get_field_groups.where(slug: "fields").any?
      group = theme.add_field_group({name: "Main Settings", slug: "fields", description: ""})
      group.add_field({"name"=>"Background color", "slug"=>"bg_color"},{field_key: "colorpicker"})
      group.add_field({"name"=>"Links color", "slug"=>"links_color"},{field_key: "colorpicker"})
      group.add_field({"name"=>"Backgroun image", "slug"=>"bg"},{field_key: "image"})
    end
    theme.set_meta("installed_at", Time.now.to_s) # save a custom value
  end

  def {theme_key}_on_uninstall_theme(theme)
    theme.destroy
  end
end