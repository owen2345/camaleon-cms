=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class SiteDecorator < TermTaxonomyDecorator
  delegate_all

  def the_description
    the_content
  end

  # return logo url for this site
  # default: this url will be returned if logo is not present.
  def the_logo(default = nil)
    object.options[:logo] || (default || "#{h.asset_url("camaleon.png")}")
  end

  def the_icon
    object.options[:icon] || '/favicon.ico'
  end

  # return all contents from this site registered for post_type = slug (filter visibility, hidden, expired, ...)
  # slug_or_id: slug or id of the post_type or array of slugs of post_types, default 'post'
  def the_contents(slug_or_id = "post")
    return h.verify_front_visibility(object.posts.where("term_taxonomy.id = ?", slug_or_id)) if slug_or_id.is_a?(Integer)
    return h.verify_front_visibility(object.posts.where("term_taxonomy.slug = ?", slug_or_id)) if slug_or_id.is_a?(String)
    return h.verify_front_visibility(object.posts.where("term_taxonomy.slug in (?)", slug_or_id)) if slug_or_id.is_a?(Array)
  end

  # return all contents for this site registered for post_type = slug (filter visibility, hidden, expired, ...)
  # slug: slug of the post_type
  # if slug is not present, then this will return all posts for this site
  def the_posts(slug_or_id = nil)
    if slug_or_id.present?
      the_contents(slug_or_id)
    else
      h.verify_front_visibility(object.posts)
    end
  end

  # return the post with id or slug equal to slug_or_id
  # slug_or_id: (String) for post slug
  # slug_or_id: (Integer) for post id
  # slug_or_id: (Array) array of post ids, return multiple posts
  # return post model or nil
  def the_post(slug_or_id)
    post = self.the_posts.find(slug_or_id) rescue nil if slug_or_id.is_a?(Integer) # id
    post = self.the_posts.find(slug_or_id) rescue nil if slug_or_id.is_a?(Array) # id
    post = self.the_posts.find_by_slug(slug_or_id) if slug_or_id.is_a?(String) # id
    post.present? ? post.decorate : nil
  end

  # return a collection of categories
  # Arguments:
  #   slug_or_id: string or integer
  # return:
    # slug_or_id: nil => return all main_categories for this site
    # slug_or_id: integer => return all main categories of the post_type with id = slug_or_id
    # slug_or_id: string => return all main categories of the post_type with slug = slug_or_id
  def the_categories(slug_or_id = nil)
    return the_post_type(slug_or_id).the_categories if slug_or_id.present?
    return object.categories unless slug_or_id.present?
  end

  # return the category object with id or slug = slug_or_id from this site
  def the_category(slug_or_id)
    return the_full_categories.where(id: slug_or_id).first.decorate rescue nil if slug_or_id.is_a?(Integer)
    return the_full_categories.find_by_slug(slug_or_id).decorate rescue nil if slug_or_id.is_a?(String)
  end

  # return all categories for ths site (include all children categories)
  def the_full_categories
    object.full_categories
  end

  # return all post tags for ths site
  def the_tags
    object.post_tags
  end

  # return the post_tag object with id or slug = slug_or_id from this site
  def the_tag(slug_or_id)
    return object.post_tags.where(id: slug_or_id).first.decorate rescue nil if slug_or_id.is_a?(Integer)
    return object.post_tags.find_by_slug(slug_or_id).decorate rescue nil if slug_or_id.is_a?(String)
  end

  # return the user object with id or username = id_or_username from this site
  def the_user(id_or_username)
    return object.users.where(id: id_or_username).first.decorate rescue nil if id_or_username.is_a?(Integer)
    return object.users.find_by_username(id_or_username).decorate rescue nil if id_or_username.is_a?(String)
  end

  # return all post types for this site
  def the_post_types
    object.post_types.eager_load(:metas)
  end

  # return a post_type object with id or slug = slug_or_id
  # Arguments:
  #   slug_or_id: string or integer
  # return:
  # slug_or_id: nil => return all main_categories for this site
  # slug_or_id: integer => return all main categories of the post_type with id = slug_or_id
  # slug_or_id: string => return all main categories of the post_type with slug = slug_or_id
  def the_post_type(slug_or_id)
    return object.post_types.find_by_slug(slug_or_id).decorate rescue nil if slug_or_id.is_a?(String)
    return object.post_types.find(slug_or_id).decorate rescue nil if slug_or_id.is_a?(Integer)
  end

  # draw languages configured for this site
  # list_class: (String) Custom css classes for ul list
  # current_page: (boolean) true: link with translation to current url, false: link with translation to root url
  def draw_languages(list_class = "language_list list-inline pull-right", current_page = false, current_class = "current_l")
    lan = object.get_languages
    return  if  lan.size < 2
    res = ["<ul class='#{list_class}'>"]
    lan.each do |lang|
      path = lang.to_s+'.png'
      img = "<img src='#{h.asset_path("language/#{path}")}'/>"
      res << "<li class='#{ current_class if I18n.locale.to_s == lang.to_s}'> <a href='#{h.url_to_fixed(current_page ? "url_for" : "root_url", {locale: lang})}'>#{img}</a> </li>"
    end
    res << "</ul>"
    res.join("")
  end

  # return Array of frontend languages configured for this site
  def the_languages
    object.get_languages
  end

  # return the role_id of current visitor for this site
  # if the visitor was not logged in, then return -1
  def visitor_role
    h.signin? ? h.current_user.get_role(object).slug : "-1"
  end

  # check if plugin_key is already installed for this site
  def plugin_installed?(plugin_key)
    res = false
    PluginRoutes.enabled_plugins(object).each{|plugin| res = true if plugin["key"] == plugin_key }
    res
  end

  # return root url for this site
  def the_url(*args)
    args = args.extract_options!
    base_domain = PluginRoutes.system_info["base_domain"]
    args[:host] = object.main_site? ? base_domain : (object.slug.include?(".") ? object.slug : "#{object.slug}.#{base_domain}" )
    args[:port] = (args[:host].split(":")[1] rescue nil)
    args[:locale] = @_deco_locale unless args.include?(:locale)
    args[:host] = args[:host].split(":").first
    args.delete(:as_path)
    h.url_to_fixed("root_url", args)
  end

  # draw bread crumb for current site
  def generate_breadcrumb(add_post_type = true)
    h.breadcrumb_add(self.the_title)
  end

  # =============================== ADMIN =======================
  # admin root url for this site
  def the_admin_url
    base_domain = PluginRoutes.system_info["base_domain"]
    host = object.main_site? ? base_domain : (object.slug.include?(".") ? object.slug : "#{object.slug}.#{base_domain}" )
    port = (host.split(":")[1] rescue nil)
    h.url_to_fixed("admin_dashboard_url", host: host, port: port, locale: false)
  end

  # check if current user can manage sites
  def manage_sites?
    self.main_site? && h.current_user.admin?
  end
end
