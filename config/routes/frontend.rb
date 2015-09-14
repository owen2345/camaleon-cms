Rails.application.routes.draw do
  scope "(:locale)", locale: /#{PluginRoutes.all_locales}/, :defaults => {  } do
    root 'frontend#index'

    controller :frontend do
      PluginRoutes.all_locales.split("|").each do |_l|
        get "#{I18n.t("routes.group", default: "group", locale: _l)}/:post_type_id-:title" => :post_type, as: "post_type_#{_l}", constraints: {post_type_id: /[0-9]+/}
        get "#{I18n.t("routes.category", default: "category", locale: _l)}/:category_id-:title" => :category, as: "category_#{_l}", constraints: {category_id: /[0-9]+/}
        get "#{I18n.t("routes.tag", default: "tag", locale: _l)}/:post_tag_id-:title" => :post_tag, as: "post_tag_#{_l}", constraints: {post_tag_id: /[0-9]+/}
        get "#{I18n.t("routes.profile", default: "profile", locale: _l)}/:user_id-:user_name" => :profile, constraints: {user_id: /[0-9]+/}, as: "profile_#{_l}"
        get "#{I18n.t("routes.search", default: "search", locale: _l)}" => :search, as: "search_#{_l}"
      end

      get 'group/:post_type_id-:title' => :post_type, as: :post_type, constraints: {post_type_id: /[0-9]+/}
      get 'category/:category_id-:title' => :category, as: :category, constraints: {category_id: /[0-9]+/}
      get 'post_tag/:post_tag_id-:title' => :post_tag, as: :post_tag, constraints: {post_tag_id: /[0-9]+/}

      get "profile/:user_id-:user_name" => :profile, as: :profile, constraints: {user_id: /[0-9]+/}
      get 'search' => :search, as: :search
      post 'save_comment/:post_id' => :save_comment, as: :save_comment
      post 'save_form' => :save_form, as: :save_form

      # sitemap
      get "sitemap" => :sitemap, as: :sitemap, defaults: { format: :xml }
      get "robots" => :robots, as: :robots, defaults: { format: :txt }
      get "rss" =>:index, defaults: { format: "rss" }
    end

    instance_eval(PluginRoutes.load("front"))

    get "*slug" => 'frontend#post', format: true, :as => :post1, defaults: { format: :html }, constraints: { slug: /(?!admin)[a-zA-Z0-9\._=\s\-]+/}
    get "*slug" => 'frontend#post', :as => :post, constraints: { slug: /(?!admin)[a-zA-Z0-9\._=\s\-]+/}
  end
end
