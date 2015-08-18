Rails.application.routes.draw do
  # root "application#index"
  default_url_options :host => PluginRoutes.system_info["base_domain"]

  # public
  get '/error.html', to: 'camaleon#render_error'
  get 'captcha', to: 'camaleon#captcha'

  eval(PluginRoutes.load("main"))
end
