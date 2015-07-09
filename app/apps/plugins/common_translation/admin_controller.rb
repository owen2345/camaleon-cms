class Plugins::CommonTranslation::AdminController < Apps::PluginsAdminController
  def index
    if params[:custom].present?
      @plugin.set_meta("custom_translations", params[:custom].to_json)
      flash[:notice] = "#{t('plugin.common_translation.message.changes_saved')}"
      redirect_to action: :index
    end
    @common_translations = YAML.load(File.read(Rails.root.join("config", "locales", "common.yml"))).with_indifferent_access
    @custom_translations = @plugin.get_meta("custom_translations")
    @site_languages = current_site.get_languages
  end

end