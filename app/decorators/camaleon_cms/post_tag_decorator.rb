class CamaleonCms::PostTagDecorator < CamaleonCms::TermTaxonomyDecorator
  delegate_all

  # return the public url for this post tag, sample: # return basic in this format: http://localhost:3000/tag/31-mytag-title.html
  def the_url(*args)
    args = args.extract_options!
    args[:post_tag_id] = the_id
    args[:title] = the_title.parameterize.presence || the_slug
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = args[:format] || "html"
    as_path = args.delete(:as_path)
    h.cama_url_to_fixed("cama_post_tag#{_calc_locale(args[:locale])}_#{as_path.present? ? "path" : "url"}", args)
  end

  # return basic url in this format: http://localhost:3000/tag/mytag.html
  def the_basic_url(*args)
    args = args.extract_options!
    args[:post_tag_slug] = the_slug
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = args[:format] || "html"
    as_path = args.delete(:as_path)
    h.cama_url_to_fixed("cama_post_tag_simple#{_calc_locale(args[:locale])}_#{as_path.present? ? "path" : "url"}", args)
  end

  # return edit url for this post
  def the_edit_url
    cama_url_helpers.edit_cama_admin_post_type_post_tag_url(object.post_type.id, object)
  end

  # return the post type of this post tag
  def the_post_type
    object.post_type.decorate
  end

  # ---------------------
  # add_post_type: true/false to include post type link
  # is_parent: true/false (internal control)
  def generate_breadcrumb(add_post_type = true, is_parent = false)
    object.post_type.decorate.generate_breadcrumb(add_post_type, true)
    h.breadcrumb_add(self.the_title)
  end
end
