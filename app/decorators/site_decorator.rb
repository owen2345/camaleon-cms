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
  # slug_or_id: slug or id of the post_type or array of slugs, default 'post'
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

  # return all main_categories for ths site
  def the_categories
    object.categories
  end

  # return the category with id or slug from this site
  def the_category(slug_or_id)
    return the_full_categories.where(id: slug_or_id).first if slug_or_id.is_a?(Integer)
    return the_full_categories.find_by_slug(slug_or_id) if slug_or_id.is_a?(String)
  end

  # return all categories for ths site (include all children categories)
  def the_full_categories
    object.full_categories
  end

  # return all post tags for ths site
  def the_tags
    object.post_tags
  end

  # return all post types for ths site
  def the_post_types
    object.post_types.eager_load(:metas)
  end

  # return the post type with slug = slug
  def the_post_type(slug)
    object.post_types.find_by_slug(slug).decorate rescue nil
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
