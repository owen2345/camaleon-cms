Rails.application.routes.draw do
  scope PluginRoutes.system_info["relative_url_root"] do
    scope module: "camaleon_cms", as: "cama" do
      namespace :admin, path: PluginRoutes.system_info["admin_path_name"] do
        get '/' => :dashboard
        get 'dashboard'
        get 'ajax'
        get 'search'
        get 'login' => 'sessions#login'
        post 'login' => 'sessions#login_post'
        get 'logout' => 'sessions#logout'
        match 'forgot' => 'sessions#forgot', via: [:get, :post, :patch]
        match 'confirm_email' => 'sessions#confirm_email', via: [:get, :post, :path]
        match 'register' => 'sessions#register', via: [:get, :post, :patch]
        match 'api/:method', action: :api, via: [:get, :post], as: :api

        resources :post_type, as: :post_type do
          resources :posts, controller: 'posts' do
            # resources :comments
            get :trash
            get :restore
            collection do
              match 'ajax', via: [:get, :post, :patch]
            end
          end

          resources :categories, controller: 'categories' do
            get 'list', on: :collection
          end
          resources :post_tags, controller: 'post_tags' do
            get 'list', on: :collection
          end
          resources :drafts, controller: 'posts/drafts'
        end

        scope 'post_type/:post_type_id/:taxonomy/:taxonomy_id', as: :post_type_taxonomy do
          get "posts" => 'posts#index'
        end

        get 'profile' => "users#profile"
        match 'profile/edit' => "users#profile_edit", via: [:get, :post, :patch]
        resources :users, controller: 'users' do
          patch 'updated_ajax'
          get :impersonate, on: :member
        end

        resources :user_roles, controller: 'user_roles' do
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
          get 'test_email'
          get 'theme'
          post 'save_theme'
          get "languages"
          get "shortcodes"
          post "languages" => :save_languages
          patch 'site_saved'

          resources :sites
        end

        get "comments" => "comments#list"
        resources :posts, only: [] do
          resources :comments, controller: 'comments' do
            get "answer"
            post "save_answer"
            get "toggle_status"
          end
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
          resources :nav_menus, except: :show do
            get 'item_delete/:id' => :delete_menu_item, as: :delete_menu_item
            get 'custom_settings/:id' => :custom_settings, as: :custom_settings
            post 'save_custom_settings/:id' => :save_custom_settings, as: :save_custom_settings
            get 'edit_menu_item/:id' => :edit_menu_item, as: :edit_menu_item
            post 'update_menu_item/:id' => :update_menu_item, as: :update_menu_item
            post 'add_items' => :add_items, as: :add_items
            post 'reorder_items' => :reorder_items, as: :reorder_items
          end

          namespace :nav_menus do # fix for previous nav menu url
            get 'menu' => :index
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

        resources :media, only: [:index] do
          match 'crop', via: :all, on: :collection
          get "ajax", on: :collection
          get "download_private_file", on: :collection
          post "upload", on: :collection
          post "actions", on: :collection
        end
      end
    end
    eval(PluginRoutes.load("admin"))
  end

  # fix to catch route not found error
  scope PluginRoutes.system_info["relative_url_root"] do
    scope module: "camaleon_cms", as: "cama" do
      namespace :admin, path: PluginRoutes.system_info["admin_path_name"] do
        get "*path" => 'admin#render_error', defaults: {error_msg: "Invalid route"}
      end
    end
  end
end
