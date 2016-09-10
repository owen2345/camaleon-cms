module CamaleonCms::ThemeHelper
  def theme_init()
    @_front_breadcrumb = []
  end

  # return theme full asset path
  # theme_name: theme name, if nil, then will use current theme
  # asset: asset file name, if asset is present return full path to this asset
  # sample: <script src="<%= theme_asset_path("js/admin.js") %>"></script> => return: /assets/themes/my_theme/assets/js/admin-54505620f.js
  def theme_asset_path(asset = nil, theme_name = nil)
    if theme_name.present? && theme_name.include?("/")
      return theme_asset_url(theme_name, current_theme.slug)
    end

    settings = theme_name.present? ? PluginRoutes.theme_info(theme_name) : current_theme.settings
    folder_name = settings["key"]
    if settings["gem_mode"]
      p = "themes/#{folder_name}/#{asset}"
    else
      p = "themes/#{folder_name}/assets/#{asset}"
    end
    p
  end
  alias_method :theme_asset, :theme_asset_path
  alias_method :theme_gem_asset, :theme_asset_path

  # return the full url for asset of current theme:
  # asset: (String) asset name
  # theme_name: (optional) theme name, default (current theme caller to this function)
  # sample:
  #   theme_asset_url("css/main.css") => return: http://myhost.com/assets/themes/my_theme/assets/css/main-54505620f.css
  def theme_asset_url(asset, theme_name = nil)
    p = theme_asset_path(asset, theme_name)
    begin
      ActionController::Base.helpers.asset_url(p)
    rescue NoMethodError => e
      p
    end
  end

  # return theme view path including the path of current theme
  # view_name: name of the view or template
  # sample: theme_view("index") => "themes/my_theme/index"
  def theme_view(view_name, deprecated_attr = "")
    view_name = deprecated_attr if deprecated_attr.present?
    if current_theme.settings["gem_mode"]
      "themes/#{current_theme.slug}/#{view_name}"
    else
      "themes/#{current_theme.slug}/views/#{view_name}"
    end
  end

  # assign the layout for this request
  # asset: asset file name, if asset is present return full path to this asset
  # layout_name: layout name
  def theme_layout(layout_name, theme_name = nil)
    if current_theme.settings["gem_mode"]
      "themes/#{current_theme.slug}/layouts/#{layout_name}"
    else
      "themes/#{current_theme.slug}/views/layouts/#{layout_name}"
    end
  end

  # return theme key for current theme file (helper|controller|view)
  # DEPRECATED, instead use: current_theme
  # index: internal control
  def self_theme_key(index = 0)
    k = "/themes/"
    f = caller[index]
    if f.include?(k)
      f.split(k).last.split("/").first
    end
  end
  
  # returns file system path to theme asset
  # theme_name: theme name, if nil, then will use current theme
  # asset: asset file name, if asset is present return full path to this asset
  # sample: theme_asset_file_path('images/foo.jpg') => return: /home/camaleon/my-site/app/apps/themes/default/assets/images/foo.jpg
  def theme_asset_file_path(asset = nil, theme_name = nil)
    theme_path = current_theme.settings['path']
    if theme_name && theme = Theme.where(name: theme_name).first
      theme_path = theme.settings['path']
    end
    "#{theme_path}/assets/#{asset}"
  end
end
