class CamaleonCms::Apps::ThemesAdminController < CamaleonCms::AdminController
  before_action :init_theme

  private

  def init_theme
    theme_name = params[:controller].split("/")[1]
    @theme = current_theme
    return render_error(404) unless current_theme.slug == theme_name
    lookup_context.prefixes.prepend(params[:controller].sub("themes/#{theme_name}", "#{theme_name}/views"))
  end
end
