module CamaleonCms::CamaleonHelper
  # create the html link with the url passed
  # verify if current user is logged in, if not, then return nil
  # return html link
  def cama_edit_link(url, title = nil, attrs = { })
    return '' unless cama_current_user.present?
    return '' unless cama_current_user.admin?
    attrs = {target: "_blank", style: "font-size:11px !important;cursor:pointer;"}.merge(attrs)
    ActionController::Base.helpers.link_to("&rarr; #{title || ct("edit", default: 'Edit')}".html_safe, url, attrs)
  end

  # execute controller action and return response
  # NON USED
  def cama_requestAction(controller,action,params={})
    controller.class_eval{
      def params=(params); @params = params end
      def params; @params end
    }
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
    r = {flag: false, key: key, translation: "", locale: language.to_sym}
    hooks_run("on_translation", r)
    return r[:translation] if r[:flag]
    I18n.translate("camaleon_cms.common.#{key}", args)
  end

  # check if current request was for admin panel
  def cama_is_admin_request?
    @cama_i18n_frontend.present?
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
      res << "<li><h4><a href='#{cat.the_url}'>#{cat.the_title}</a></h4><ul>#{res_posts.join("")}</ul></li>"
      res << cama_sitemap_cats_generator(cat.the_categories)
    end
    res.join("")
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

  # =Deprecated
  def cama_draw_timer
    @_cama_timer ||= Time.current
    puts "***************************************** timer: #{((Time.current - @_cama_timer) * 24 * 60 * 60).to_i}  (#{caller.first})"
    @_cama_timer = Time.current
  end

  # return normal translation with default value with translation of english
  def cama_t(key, args = {})
    args[:default] = I18n.t(key, args.dup.merge(locale: :en)) unless args[:default].present?
    I18n.t(key, args)
  end
end
