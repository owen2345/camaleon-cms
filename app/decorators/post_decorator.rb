=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class PostDecorator < ApplicationDecorator
  include CustomFieldsConcern
  delegate_all


  def the_title
    r = {title: object.title.to_s.translate(get_locale), post: object}
    h.hooks_run("post_the_title", r)
    r[:title]
  end

  # return the excerpt of this post
  def the_excerpt(qty_chars = 200)
    excerpt = object.meta[:summary].to_s.translate(get_locale)
    r = {content: (excerpt.present? ? excerpt : object.content.to_s.translate(get_locale).strip_tags.gsub(/&#13;|\n/, " ").truncate(qty_chars)), post: object}
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
    th = object.meta[:thumb]
    th.present? ? th : (default || object.post_type.get_option('default_thumb', nil) || h.asset_url("image-not-found.png"))
  end

  # check if this page has registered the thumbnail
  def has_thumb?
    object.meta[:thumb].present?
  end

  # return front url for this post
  def the_url(*args)
    args = args.extract_options!
    args[:slug] = the_slug
    args[:locale] = get_locale unless args.include?(:locale)
    args[:format] = "html"
    as_path = args.delete(:as_path)
    h.url_to_fixed("post_#{as_path.present? ? "path" : "url"}", args)
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
    h.edit_admin_post_type_post_url(object.post_type.id, object)
  end

  # create the html link with edit link
  # return html link
  # attrs: Hash of link tag attributes, sample: {id: "myid", class: "sss" }
  def the_edit_link(title = nil, attrs = { })
    attrs = {target: "_blank", style: "font-size:11px !important;cursor:pointer;"}.merge(attrs)
    h.link_to("&rarr; #{title || h.ct("edit")}", the_edit_url, *attrs)
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
        status = I18n.t('admin.post_type.published')
      when "draft"
        color = "warning"
        status = I18n.t('admin.table.draft')
      when "trash"
        color = "danger"
        status = I18n.t('admin.table.trash')
      when "pending"
        color = "default"
        status = I18n.t('admin.table.pending')
      else
        color = "default"
        status = self.status
    end
    "<span class='label label-#{color} label-form'>#{status.titleize}</span>"
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

  # check if the post can be commented
  def can_commented?
    object.meta[:has_comments].to_s.to_bool rescue false
  end


  # add_post_type: true/false to include post type link
  # children: true/false (show/hide last item link)
  # show_categories: true/false, true: add categories tree to the breadcrumb
  def generate_breadcrumb(show_categories = true, add_post_type = true)
    f_cat = object.categories.first
    if f_cat.present? && show_categories
      f_cat.decorate.generate_breadcrumb(add_post_type, true)
    else
      object.post_type.decorate.generate_breadcrumb(add_post_type, true)
    end
    h.breadcrumb_add(self.the_title)
  end

  # return the post type of this post
  def the_post_type
    object.post_type.decorate
  end

  # cache identifier, the format is: [current-site-prefix]/[object-id]-[object-last_updated]/[current locale]
  # key: additional key for the model
  def cache_prefix(key = "")
    "#{h.current_site.cache_prefix}/post#{object.id}#{"/#{key}" if key.present?}"
  end
end
