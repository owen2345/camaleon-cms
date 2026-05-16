module CamaleonCms
  module CamaleonHelper
    # create the html link with the url passed
    # verify if current user is logged in, if not, then return nil
    # return html link
    def cama_edit_link(url, title = nil, attrs = {})
      return '' if cama_current_user.blank?
      return '' unless cama_current_user.admin?

      attrs = { target: '_blank', style: 'font-size:11px !important;cursor:pointer;' }.merge(attrs)
      link_to(
        safe_join(['→ ', title || ct('edit', default: 'Edit')]),
        url,
        attrs
      )
    end

    # execute controller action and return response
    # NON USED
    def cama_requestAction(controller, action, params = {})
      controller.class_eval do
        def params=(params)
          @params = params
        end

        def params
          @params
        end
      end
      c = controller.new
      c.request = @_request
      c.response = @_response
      c.params = params
      c.send(action)
      c.response.body
    end

    # theme common translation text
    # key: key for translation
    # args: hash of arguments for i18n.t()
    # database customized translations
    def ct(key, args = {})
      language = I18n.locale
      r = { flag: false, key: key, translation: '', locale: language.to_sym }
      hooks_run('on_translation', r)
      return r[:translation] if r[:flag]

      I18n.translate("camaleon_cms.common.#{key}", **args)
    end

    # generate loop categories html sitemap links
    # this is a helper for sitemap generator to print categories, sub categories and post contents in html list format
    def cama_sitemap_cats_generator(cats)
      res = []
      cats.decorate.each do |cat|
        next if @r[:skip_cat_ids].include?(cat.id)

        res_posts = []
        cat.the_posts.decorate.each do |post|
          next if @r[:skip_post_ids].include?(post.id)

          res_posts << "<li><a href='#{post.the_url}'>#{post.the_title}</a></li>"
        end
        res << "<li><h4><a href='#{cat.the_url}'>#{cat.the_title}</a></h4><ul>#{res_posts.join('')}</ul></li>"
        res << cama_sitemap_cats_generator(cat.the_categories)
      end
      res.join('')
    end

    # save value as cache instance and return value
    # sample: cama_cache_fetch("my_key"){ 10+20*12 }
    def cama_cache_fetch(var_name)
      var_name = "@cama_cache_#{var_name}"
      return instance_variable_get(var_name) if instance_variable_defined?(var_name)

      cache = yield
      instance_variable_set(var_name, cache)
      cache
    end

    # return normal translation with default value with translation of english
    def cama_t(key, args = {})
      args[:default] = I18n.t(key, **args.dup.merge(locale: :en)) if args[:default].blank?
      I18n.t(key, **args)
    end

    # function that converts string into plural format
    def cama_pluralize_text(text)
      text.try(:pluralize)
    end
  end
end
