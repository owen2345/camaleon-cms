class CamaleonCms::PostDecorator < CamaleonCms::ApplicationDecorator
  include CamaleonCms::CustomFieldsConcern
  delegate_all


  def the_title(locale = nil)
    r = {title: object.title.to_s.translate(get_locale(locale)), post: object}
    h.hooks_run("post_the_title", r)
    r[:title]
  end

  # return the excerpt of this post
  def the_excerpt(qty_chars = 200)
    excerpt = object.get_meta("summary").to_s.translate(get_locale)
    # r = {content: (excerpt.present? ? excerpt : object.content_filtered.to_s.translate(get_locale).strip_tags.gsub(/&#13;|\n/, " ").truncate(qty_chars)), post: object}
    r = {content: (excerpt.present? ? excerpt : h.cama_strip_shortcodes(object.content_filtered.to_s.translate(get_locale).strip_tags.gsub(/&#13;|\n/, " ").truncate(qty_chars))), post: object}
    h.hooks_run("post_the_excerpt", r)
    r[:content]
  end

  # return the content of this post
  def the_content
    r = {content: object.content.to_s.translate(get_locale), post: object}
    h.hooks_run("post_the_content", r)
    h.do_shortcode(r[:content], self)
  end

  # return thumbnail image for this post
  # default: default image if thumbails not exist
  # if default is empty, post_type default thumb will be returned
  def the_thumb_url(default = nil)
    th = object.get_meta("thumb")
    th.present? ? th : (default || object.post_type.get_option('default_thumb', nil) || h.asset_url("camaleon_cms/image-not-found.png"))
  end
  alias_method :the_image_url, :the_thumb_url

  # check if this page has registered the thumbnail
  def has_thumb?
    object.get_meta("thumb").present?
  end

  # return the path for this page
  # sample: /my-page.html
  def the_path(*args)
    args = args.extract_options!
    args[:as_path] = true
    the_url(args)
  end

  # return front url for this post
  # sample: http://localhost.com/my-page.html
  # args:
  #   locale: language (default current language)
  #   as_path: return the path instead of full url, sample: /my-page.html
  #   Also, you can pass extra attributes as params for the url, sample: page.the_url(my_param: 'value', other: "asd")
  #     => http://localhost.com/my-page.html?my_param=value&other=asd
  # Return String URL
  def the_url(*args)
    args = args.extract_options!
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = args[:format] || "html"
    args[:slug] = the_slug(args[:locale])
    p = args.delete(:as_path).present? ? "path" : "url"
    l = _calc_locale(args[:locale])
    ptype = object.post_type.decorate
    p_url_format = ptype.contents_route_format
    p_url_format = "hierarchy_post" if ptype.manage_hierarchy?
    case p_url_format
      when "post_of_post_type"
        args[:label] = I18n.t('routes.group', default: 'group')
        args[:post_type_id] = ptype.id
        args[:title] = ptype.the_title(args[:locale]).parameterize.presence || ptype.the_slug
      when "post_of_category"
        if ptype.manage_categories?
          cat = object.categories.first.decorate rescue ptype.default_category.decorate
          args[:label_cat] = I18n.t("routes.category", default: "category")
          args[:category_id] = cat.id
          args[:title] = cat.the_title(args[:locale]).parameterize
          args[:title] = cat.the_slug unless args[:title].present?
        else
          p_url_format = "post"
        end
      when "post_of_posttype"
        args[:post_type_title] = ptype.the_title(args[:locale]).parameterize.presence || ptype.the_slug
      when "post_of_category_post_type"
        if ptype.manage_categories?
          cat = object.categories.first.decorate rescue ptype.default_category.decorate
          args[:label_cat] = I18n.t("routes.category", default: "category")
          args[:post_type_title] = ptype.the_title(args[:locale]).parameterize.presence || ptype.the_slug
          args[:category_id] = cat.id
          args[:title] = cat.the_title(args[:locale]).parameterize
          args[:title] = cat.the_slug unless args[:title].present?
        else
          p_url_format = "post"
        end
      when 'hierarchy_post'
        if object.post_parent.present?
          slugs = ([args[:slug]]+object.parents.map{|parent| parent.decorate.the_slug(args[:locale]) }).reverse
          args[:slug], args[:parent_title] = slugs.slice(1..-1).join("/"), slugs.first
        else
          p_url_format = "post"
        end
    end
    h.cama_url_to_fixed("cama_#{p_url_format}_#{p}", args)
  end

  # return a hash of frontend urls for this post
  # sample: {es: 'http://mydomain.com/es/articulo-3.html', en: 'http://mydomain.com/en/post-3.html'}
  def the_urls(*args)
    args = args.extract_options!
    res = {}
    h.current_site.the_languages.each do |l|
      args[:locale] = l
      res[l] = the_url(args.clone)
    end
    res
  end

  # return edit url for this post
  def the_edit_url
    args = h.cama_current_site_host_port({})
    h.edit_cama_admin_post_type_post_url(object.post_type.id, object, args)
  end

  # create the html link with edit link
  # return html link
  # attrs: Hash of link tag attributes, sample: {id: "myid", class: "sss" }
  def the_edit_link(title = nil, attrs = { })
    return '' unless h.cama_current_user.present?
    attrs = {target: "_blank", style: "font-size:11px !important;cursor:pointer;"}.merge(attrs)
    h.link_to("&rarr; #{title || h.ct("edit", default: 'Edit')}".html_safe, the_edit_url, attrs)
  end

  # show thumbnail image as html
  def the_thumb(img_args = {})
    r = {image: h.image_tag(the_thumb_url, img_args), post: object}
    h.hooks_run("post_the_thumb", r)
    r[:image]
  end

  # show link and thumbnail included as html
  # link_args: html attributes for link
  # img_args: html attributes for image
  def the_link_thumb(link_args = {}, img_args = {})
    h.link_to(the_thumb(img_args), the_url, link_args)
  end

  def the_status
    case self.status
      when "published"
        color = "info"
        status = I18n.t('camaleon_cms.admin.post_type.published', default: 'Published')
      when "draft"
        color = "warning"
        status = I18n.t('camaleon_cms.admin.table.draft', default: 'Draft')
      when "trash"
        color = "danger"
        status = I18n.t('camaleon_cms.admin.table.trash', default: 'Trash')
      when "pending"
        color = "default"
        status = I18n.t('camaleon_cms.admin.table.pending', default: 'Pending')
      else
        color = "default"
        status = self.status
    end
    "<span class='label label-#{color} label-form'>#{status.titleize}</span>"
  end

  # return the user object who created this post
  def the_author
    object.author.decorate
  end

  # return all categories assigned for this post filtered by permissions + hidden posts + roles + etc...
  def the_categories
    object.categories
  end

  # return all post_tags assigned for this post
  def the_tags
    object.post_tags
  end

  # return all comments for this post filtered by permissions + hidden posts + roles + etc...
  def the_comments
    object.comments.main.approveds.eager_load(:user)
  end

  # check if the post can be visited by current visitor
  def can_visit?
    r = {flag: true, post: object}
    h.hooks_run("post_can_visit", r)
    r[:flag] && object.status == 'published'
  end

  # add_post_type: true/false to include post type link
  # children: true/false (show/hide last item link)
  # show_categories: true/false, true: add categories tree to the breadcrumb
  def generate_breadcrumb(show_categories = true, add_post_type = true)
    p_type = object.post_type
    f_cat = object.categories.first
    if f_cat.present? && show_categories
      f_cat.decorate.generate_breadcrumb(add_post_type, true)
    else
      p_type.decorate.generate_breadcrumb(add_post_type, true)
    end
    object.parents.reverse.each{|p| p=p.decorate; h.breadcrumb_add(p.the_title, p.published? ? p.the_url : nil) } if object.post_parent.present? && p_type.manage_hierarchy?
    h.breadcrumb_add(self.the_title)
  end

  # return the post type of this post
  def the_post_type
    object.post_type.decorate
  end

  # return the title with hierarchy prefixed
  # sample: title paren 1 - title parent 2 -.. -...
  # if add_parent_title: true will add parent title like: —— item 1.1.1 | item 1.1
  def the_hierarchy_title
    return the_title unless object.post_parent.present?
    res = '&#8212;' * object.parents.count
    res << " " + the_title
    res << " | #{object.parent.decorate.the_title}" if object.show_title_with_parent
    res.html_safe
  end

  # return all related posts of current post
  def the_related_posts
    ptype = self.the_post_type
    ptype.the_posts.joins(:categories).where("#{CamaleonCms::TermRelationship.table_name}" => {term_taxonomy_id: the_categories.pluck(:id)})
  end

  # fix for "Using Draper::Decorator without inferred source class"
  def self.object_class_name
    'CamaleonCms::Post'
  end
end
