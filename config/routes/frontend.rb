Rails.application.routes.draw do

  # frontend plugins
  scope PluginRoutes.system_info["relative_url_root"] do
    scope "(:locale)", locale: /#{PluginRoutes.all_locales}/, :defaults => {  } do
      instance_eval(PluginRoutes.load("front"))
    end
  end

  # frontend camaleon cms
  scope PluginRoutes.system_info["relative_url_root"], as: "cama" do
    scope "(:locale)", locale: /#{PluginRoutes.all_locales}/, :defaults => {  } do
      root 'camaleon_cms/frontend#index', as: 'root'

      controller "camaleon_cms/frontend" do
        get :index
        get ':label/:post_type_id-:title' => :post_type, as: 'post_type', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.group', default: 'group')
          request.params[:post_type_id].match(/[0-9]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label/:post_type_id-:title/:slug' => :post, as: 'post_of_post_type', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.group', default: 'group')
          request.params[:post_type_id].match(/[0-9]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label/:category_id-:title' => :category, as: 'category', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.category', default: 'category')
          request.params[:category_id].match(/[0-9]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label_cat/:category_id-:title/:slug' => :post, as: 'post_of_category', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.category', default: 'category')
          request.params[:category_id].match(/[0-9]+/) && request.params[:label_cat].in?(multilingual_segment)
        }
        get ':post_type_title/:label_cat/:category_id-:title/:slug' => :post, as: 'post_of_category_post_type', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.category', default: 'category')
          request.params[:post_type_title].match(/^(?!(#{PluginRoutes.all_locales})$)[\w\.\-]+$/) &&
            request.params[:category_id].match(/[0-9]+/) && request.params[:label_cat].in?(multilingual_segment)
        }
        get ':label/:post_tag_id-:title' => :post_tag, as: 'post_tag', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.tag', default: 'tag')
          request.params[:post_tag_id].match(/[0-9]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label/:post_tag_id-:title/:slug' => :post, as: 'post_of_tag', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.tag', default: 'tag')
          request.params[:post_tag_id].match(/[0-9]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label/:post_tag_slug' => :post_tag, as: 'post_tag_simple', constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.tag', default: 'tag')
          request.params[:post_tag_slug].match(/[a-zA-Z0-9_=\s\-\/]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label/:user_id-:user_name' => :profile, as: :profile, defaults:{label: 'profile'}, constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.profile', default: 'profile') | %w(profile)
          request.params[:user_id].match(/[0-9]+/) && request.params[:label].in?(multilingual_segment)
        }
        get ':label' => :search, as: :search, defaults:{label: 'search'}, constraints: ->(request) {
          multilingual_segment = PluginRoutes.all_translations('routes.search', default: 'search') | %w(search)
          request.params[:label].in?(multilingual_segment)
        }

        get ':post_type_title/:slug' => :post, as: :post_of_posttype, constraints: ->(request) {
          request.params[:post_type_title].match(/^(?!(#{PluginRoutes.all_locales})$)[\w\.\-]+$/)
        }

        post 'save_comment/:post_id' => :save_comment, as: :save_comment
        post 'save_form' => :save_form, as: :save_form

        # sitemap
        get "sitemap" => :sitemap, as: :sitemap, defaults: { format: :xml }
        get "robots" => :robots, as: :robots, defaults: { format: :txt }
        get "rss", defaults: { format: "rss" }
        get "ajax"

        # post types
        controller "camaleon_cms/frontend" do
          PluginRoutes.get_sites.each do |s|
            s.post_types.pluck(:slug, :id).each do |pt_slug, pt_id|
              get ':post_type_slug' => :post_type, as: "post_type_#{pt_id}", post_type_id: pt_id, constraints: ->(request) {
                multilingual_segment = PluginRoutes.all_translations("routes.post_types.#{pt_slug}", default: pt_slug)
                request.params[:post_type_slug].in?(multilingual_segment)
              }
            end
          end
        end

        # posts
        constraints(format: /html|rss|json/) do
          get ':parent_title/*slug(.:format)' => :post, as: :hierarchy_post, constraints: ->(request) {
            request.params[:parent_title].match(/^(?!(#{PluginRoutes.all_locales})$)[\w\-]+$/) &&
              request.params[:slug].match(/[a-zA-Z0-9_=\s\-\/]+/)
          }
          get ":slug(.:format)" => :post, :as => :post, constraints: { slug: /[a-zA-Z0-9_=\s\-]+/}
        end
      end
    end
  end

end
