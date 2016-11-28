class CamaleonCms::TermTaxonomyDecorator < CamaleonCms::ApplicationDecorator
  include CamaleonCms::CustomFieldsConcern
  delegate_all

  # return the title for current locale
  def the_title(locale = nil)
    r = {title: object.name.translate(get_locale(locale)), object: object}
    h.hooks_run("taxonomy_the_title", r) rescue nil # avoid error for command the_url for categories
    r[:title]
  end

  # return the slug for current locale
  def the_slug
    object.slug.translate(get_locale)
  end

  # return the content for current locale + shortcodes executed
  def the_content
    r = {content: object.description.to_s.translate(get_locale), object: object}
    h.hooks_run("taxonomy_the_content", r)
    h.do_shortcode(r[:content], self)
  end

  def the_status
    if status.to_s.to_bool
      "<span class='label label-success'> #{I18n.t('camaleon_cms.admin.button.actived')} </span>"
    else
      "<span class='label label-default'> #{I18n.t('camaleon_cms.admin.button.not_actived')} </span>"
    end
  end

  # return excerpt for this post type
  # qty_chars: total or characters maximum
  def the_excerpt(qty_chars = 200)
    r = {content: object.description.to_s.translate(get_locale).strip_tags.gsub(/&#13;|\n/, " ").truncate(qty_chars), object: object}
    h.hooks_run("taxonomy_the_excerpt", r)
    r[:content]
  end

  # ---------------------- filters
  # return all posts for this model (active_record) filtered by permissions + hidden posts + roles + etc...
  # in return object, you can add custom where's or pagination like here:
  # http://edgeguides.rubyonrails.org/active_record_querying.html
  def the_posts
    h.verify_front_visibility(object.posts)
  end

  # search a post with id (integer) or slug (string)
  def the_post(slug_or_id)
    return nil unless slug_or_id.present?
    return object.posts.where(id: slug_or_id).first.decorate rescue nil if slug_or_id.is_a?(Integer)
    return object.posts.find_by_slug(slug_or_id).decorate rescue nil if slug_or_id.is_a?(String)
  end

  # return edit url for current taxonomy: PostType, PostTag, Category
  def the_edit_url
    args = h.cama_current_site_host_port({})
    case object.class.name
      when "CamaleonCms::PostType"
        h.edit_cama_admin_settings_post_type_url(object, args)
      when "CamaleonCms::Category"
        h.edit_cama_admin_post_type_category_url(object.post_type.id, object, args)
      when "CamaleonCms::PostTag"
        h.edit_cama_admin_post_type_post_tag_url(object.post_type.id, object, args)
      when "CamaleonCms::Site"
        h.cama_admin_settings_site_url(args)
      else
        ""
    end
  end

  # create the html link with edit link
  # return html link
  # attrs: Hash of link tag attributes, sample: {id: "myid", class: "sss" }
  def the_edit_link(title = nil, attrs = { })
    return '' unless h.cama_current_user.present?
    attrs = {target: "_blank", style: "font-size:11px !important;cursor:pointer;"}.merge(attrs)
    h.link_to("&rarr; #{title || h.ct("edit", default: 'Edit')}".html_safe, the_edit_url, attrs)
  end

  # return the user owner of this item
  # sample: my_item.the_owner.the_url
  def the_owner
    owner.decorate rescue nil
  end

  # return the parent item of this item
  # sample: my_item.the_parent.the_url
  def the_parent
    parent.decorate rescue nil
  end

end
