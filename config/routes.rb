Rails.application.routes.draw do
  # root "application#index"
  default_url_options :host => PluginRoutes.system_info["base_domain"]

  # public
  get '/error.html', to: 'camaleon#render_error'
  get 'captcha', to: 'camaleon#captcha'

  #API
  get '/api/index', to: 'whatever#index'
  # namespace :api, :defaults => {:format => :json} do
  #   namespace :v1 do
  #     controller :whatever, path: '/whatever' do
  #       match 'post_action', via: [:post, :options]
  #     end
  #   end
  # end

  eval(PluginRoutes.load("main"))
end
