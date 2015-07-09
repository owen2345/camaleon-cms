WPRails::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
  default_url_options :host => PluginRoutes.system_info["base_domain"]

  # public

  get '/error.html', to: 'application#render_error'
  get 'captcha', to: 'application#captcha'

  eval(PluginRoutes.load("main"))
end
