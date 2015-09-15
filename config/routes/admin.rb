Rails.application.routes.draw do
  namespace :admin do
    get '/' => :dashboard
    get 'dashboard'
    get 'media' => 'media#index'
    get 'login' => 'sessions#login'
    post 'login' => 'sessions#login_post'
    get 'logout' => 'sessions#logout'
    match 'forgot' => 'sessions#forgot', via: [:get, :post, :patch]
    match 'register' => 'sessions#register', via: [:get, :post, :patch]
    match 'api/:method', action: :api, via: [:get, :post], as: :api

    # grid editor administration
    resources :grid_editor

    resources :post_type , as: :post_type do
      resources :posts, controller: 'posts' do
        # resources :comments
        get :trash
        get :restore
        collection do
          match 'ajax', via: [:get, :post, :patch]
        end
      end

      resources :categories, controller: 'categories'
      resources :post_tags, controller: 'post_tags' do
        collection do
          get 'list'
        end
      end
      resources :drafts, controller: 'posts/drafts'
    end

    scope 'post_type/:post_type_id/:taxonomy/:taxonomy_id' , as: :post_type_taxonomy do
      get "posts" => 'posts#index'
    end

    get 'profile' => "users#profile"
    match 'profile/edit' => "users#profile_edit", via: [:get, :post, :patch]
    resources :users, controller: 'users'  do
      patch 'updated_ajax'
    end
    resources :user_roles, controller: 'user_roles'  do
    end

    namespace :settings do
      resources :post_types

      resources :custom_fields do
        collection do
          post 'get_items/:key', action: :get_items, as: :get_items
          post "reorder"
        end
      end

      get 'site'
      get "languages"
      post "languages" => :save_languages
      patch 'site_saved'

      resources :sites
    end

    resources :comments, controller: 'comments' do
      collection do
        match 'responses', via: [:get, :post, :patch]
        delete 'destroy_comments' => 'comments#destroy_comments'
        post 'delete' => 'comments#delete'
      end
      post 'change_status' => 'comments#change_status'
    end

    namespace :appearances do

      match 'widgets', via: [:get, :delete]
      match 'widgets_save', via: [:post, :patch]
      match 'widget_delete', via: [:get, :patch]
      get 'render_form'

      resources :themes, only: [:index] do
        collection do
          get "preview"
          # match "settings", via: [:get, :post, :patch]
          match "load_data", via: [:get, :post, :patch]
        end
      end

      namespace :nav_menus do
        match 'menu', via: [:get, :delete]
        post 'save'
        get 'form'
      end

      namespace :widgets do
        resources :main, except: [:show]
        resources :sidebar, except: [:show] do
          post "reorder"
          resources :assign, except: [:index, :show]
        end
      end
    end

    resources :plugins, only: [:index, :destroy] do
      get "toggle", on: :collection
      get "upgrade"
    end

    # installer
    resources :installers, only: [:index] do
      post "save", on: :collection
      get "welcome", on: :collection
    end

    match 'elfinder' => 'media#elfinder', via: :all
    match 'elfinder/iframe' => 'media#iframe', via: :all
    match 'crop' => 'media#crop', via: :all
  end

  eval(PluginRoutes.load("admin"))
end
