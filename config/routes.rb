Rails.application.routes.draw do
  scope PluginRoutes.system_info["relative_url_root"], as: "cama" do
    # root "application#index"
    default_url_options PluginRoutes.default_url_options

    # public
    get 'error', as: "error", to: 'camaleon_cms/camaleon#render_error'
    get 'captcha', as: "captcha", to: 'camaleon_cms/camaleon#captcha'
    eval(PluginRoutes.load("main"))
  end
end
