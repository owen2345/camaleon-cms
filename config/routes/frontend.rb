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
        get ":label/:post_type_id-:title" => :post_type, as: "post_type", constraints: {post_type_id: /[0-9]+/, label: /(#{PluginRoutes.all_translations('routes.group', default: 'group').join('|')})/}
        get ":label/:post_type_id-:title/:slug" => :post, as: "post_of_post_type", constraints: {post_type_id: /[0-9]+/, label: /(#{PluginRoutes.all_translations('routes.group', default: 'group').join('|')})/}
        get ":label/:category_id-:title" => :category, as: "category", constraints: {category_id: /[0-9]+/, label: /(#{PluginRoutes.all_translations('routes.category', default: 'category').join('|')})/}
        get ":label_cat/:category_id-:title/:slug" => :post, as: "post_of_category", constraints: {category_id: /[0-9]+/, label_cat: /(#{PluginRoutes.all_translations('routes.category', default: 'category').join('|')})/}
        get ":post_type_title/:label_cat/:category_id-:title/:slug" => :post, as: "post_of_category_post_type", constraints:{ post_type_title: /(?!(#{PluginRoutes.all_locales}))[\w\.\-]+/, category_id: /[0-9]+/, label_cat: /(#{PluginRoutes.all_translations('routes.category', default: 'category').join('|')})/ }
        get ":label/:post_tag_id-:title" => :post_tag, as: "post_tag", constraints: {post_tag_id: /[0-9]+/, label: /(#{PluginRoutes.all_translations('routes.tag', default: 'tag').join('|')})/}
        get ":label/:post_tag_id-:title/:slug" => :post, as: "post_of_tag", constraints: {post_tag_id: /[0-9]+/, label: /(#{PluginRoutes.all_translations('routes.tag', default: 'tag').join('|')})/}
        get ":label/:post_tag_slug" => :post_tag, as: "post_tag_simple", constraints: {post_tag_slug: /[a-zA-Z0-9_=\s\-\/]+/, label: /(#{PluginRoutes.all_translations('routes.tag', default: 'tag').join('|')})/}
        get ":label/:user_id-:user_name" => :profile, as: :profile, defaults:{label: 'profile'}, constraints: {user_id: /[0-9]+/, label: /(#{PluginRoutes.all_translations('routes.profile', default: 'profile').join('|')})/}
        get ":label" => :search, as: :search, defaults:{label: 'search'}, constraints: {label: /(#{PluginRoutes.all_translations('routes.search', default: 'search').join('|')})/}

        get ':post_type_title/:slug' => :post, as: :post_of_posttype, constraints:{ post_type_title: /(?!(#{PluginRoutes.all_locales}))[\w\.\-]+/ }

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
              get ":post_type_slug" => :post_type, as: "post_type_#{pt_id}", post_type_id: pt_id, constraints: {post_type_slug: /(#{PluginRoutes.all_locales.split("|").map{|_l| I18n.t("routes.post_types.#{pt_slug}", default: pt_slug, locale: _l) }.uniq.join('|') })/}
            end
          end
        end

        # posts
        constraints(format: /html|rss|json/) do
          get ':parent_title/*slug(.:format)' => :post, as: :hierarchy_post, constraints:{ parent_title: /(?!(#{PluginRoutes.all_locales}))[\w\-]+/, slug: /[a-zA-Z0-9_=\s\-\/]+/ }
          get ":slug(.:format)" => :post, :as => :post, constraints: { slug: /[a-zA-Z0-9_=\s\-]+/}
        end
      end
    end
  end

end
