Rails.application.routes.draw do
  scope PluginRoutes.system_info['relative_url_root'] do
    scope module: 'camaleon_cms', as: 'cama' do
      namespace :admin, path: PluginRoutes.system_info['admin_path_name'] do
        get '/' => :dashboard
        get 'dashboard'
        get 'ajax'
        get 'search'
        get 'login' => 'sessions#login'
        post 'login' => 'sessions#login_post'
        # Security (audit M6): logout changes state, so it acts only over POST. The GET renders a
        # confirmation page instead of 404ing -- frontend themes across the ecosystem link this
        # path -- and the impersonation flow keeps its redirect (see SessionsController#logout).
        match 'logout' => 'sessions#logout', via: %i[get post]
        match 'back_to_parent' => 'sessions#back_to_parent', via: %i[get post]
        match 'forgot' => 'sessions#forgot', via: %i[get post patch]
        match 'confirm_email' => 'sessions#confirm_email', via: %i[get post patch]
        match 'register' => 'sessions#register', via: %i[get post patch]
        match 'api/:method', action: :api, via: %i[get post], as: :api

        resources :post_type, as: :post_type do
          resources :posts, controller: 'posts' do
            # resources :comments
            # Security (audit M6): state-changing member actions must not ride GET links.
            patch :trash
            patch :restore
            collection do
              match 'ajax', via: %i[get post patch]
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
          get 'posts' => 'posts#index'
        end

        get 'profile' => 'users#profile'
        match 'profile/edit' => 'users#profile_edit', via: %i[get post patch]
        resources :users, controller: 'users' do
          patch 'updated_ajax'
          # Security (audit M6): forces a session switch -- the highest-value CSRF target here.
          post :impersonate, on: :member
        end

        resources :user_roles, controller: 'user_roles' do
        end

        namespace :settings do
          resources :post_types
          resources :custom_fields do
            collection do
              post 'get_items/:key', action: :get_items, as: :get_items
              post 'reorder'
              match 'list', via: %i[get post]
            end
          end
          get 'site'
          post 'test_email' # Security (audit M6): sends mail; must not be a CSRF-able GET
          get 'theme'
          post 'save_theme'
          get 'languages'
          get 'shortcodes'
          post 'languages' => :save_languages
          patch 'site_saved'

          resources :sites
        end

        get 'comments' => 'comments#list'
        resources :posts, only: [] do
          resources :comments, controller: 'comments' do
            get 'answer'
            post 'save_answer'
            patch 'toggle_status' # Security (audit M6): flips moderation state
          end
        end

        namespace :appearances do
          # Security (audit M6): this legacy widgets surface predates the widgets/{main,sidebar,
          # assign} controllers (its target controller is long gone) but still declared delete
          # endpoints reachable over CSRF-exempt GET. The non-GET verbs keep the paths and helpers
          # routable for any external binding.
          delete 'widgets'
          match 'widgets_save', via: %i[post patch]
          patch 'widget_delete'
          get 'render_form'

          resources :themes, only: [:index] do
            collection do
              get 'preview'
              # match "settings", via: [:get, :post, :patch]
              # Security (audit M6): load_data clears and re-imports post types, nav menus and sliders
              # -- a state change that must not ride a CSRF-exempt GET link.
              match 'load_data', via: %i[post patch]
            end
          end
          resources :nav_menus, except: :show do
            # Security (audit M6): destroys a menu item -- must not ride a CSRF-exempt GET. The
            # admin JS sends a token-bearing DELETE (nav_menu.js).
            delete 'item_delete/:id' => :delete_menu_item, as: :delete_menu_item
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
              post 'reorder'
              resources :assign, except: %i[index show]
            end
          end
        end

        resources :plugins, only: %i[index destroy] do
          # Security (audit M6): activating/deactivating and upgrading a plugin run install and
          # upgrade hooks -- state changes, not reads.
          patch 'toggle', on: :collection
          post 'upgrade'
        end

        # installer
        resources :installers, only: [:index] do
          post 'save', on: :collection
          get 'welcome', on: :collection
        end

        resources :media, only: [:index] do
          # Security (audit M6): crop writes a cropped upload and can rewrite a user avatar
          # (saved_avatar); via: :all admitted every verb, the CSRF-exempt GET/HEAD included.
          post 'crop', on: :collection
          get 'ajax', on: :collection
          get 'download_private_file', on: :collection
          post 'upload', on: :collection
          post 'actions', on: :collection
        end
      end
    end
    eval(PluginRoutes.load('admin'))
  end

  # fix to catch route not found error
  scope PluginRoutes.system_info['relative_url_root'] do
    scope module: 'camaleon_cms', as: 'cama' do
      namespace :admin, path: PluginRoutes.system_info['admin_path_name'] do
        get '*path' => :render_error, defaults: { error_msg: 'Invalid route' }
      end
    end
  end
end
