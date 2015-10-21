Rails.application.routes.draw do
  use_doorkeeper

  namespace :api do
    get 'account' => 'api#account'

    namespace :v1 do
      get 'categories' => 'category#categories'
      get 'posts' => 'post#index'
      get 'pages' => 'page#index'

      scope :contact_form do
        get 'show/:slug' => 'contact_form#contact_form_by_slug'
        post 'create' => 'contact_form#save_form'
      end
    end
  end

  # root "application#index"
  default_url_options :host => PluginRoutes.system_info["base_domain"]

  # public
  get '/error.html', to: 'camaleon#render_error'
  get 'captcha', to: 'camaleon#captcha'

  eval(PluginRoutes.load("main"))
end
