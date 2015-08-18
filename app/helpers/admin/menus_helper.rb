=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Admin::MenusHelper
  include Admin::BreadcrumbHelper

  def admin_menus_add_commons
    admin_menu_add_menu("dashabord", {icon: "dashboard", title: t('admin.sidebar.dashboard'), url: admin_dashboard_path})
    #if can? :manager, :content
      items = []

      current_site.post_types.eager_load(:metas).visible_menu.all.each do |pt|
        pt = pt.decorate
        items_i = []
        items_i << {icon: "list", title: "#{t('admin.post_type.all')}", url: admin_post_type_posts_path(pt.id)} if can? :posts, pt
        items_i << {icon: "plus", title: "#{t('admin.post_type.add_new')}  ", url: new_admin_post_type_post_path(pt.id)} if can? :create_post, pt
        if pt.manage_categories?
          items_i << {icon: "folder-open", title: t('admin.post_type.categories'), url: admin_post_type_categories_path(pt.id)} if can? :categories, pt
        end
        if pt.manage_tags?
          items_i << {icon: "tags", title: t('admin.post_type.tags'), url: admin_post_type_post_tags_path(pt.id)} if can? :post_tags, pt
        end
        items << {icon: "file-o", title: pt.the_title, url: "", items: items_i} if items_i.present? #if can? :posts, pt
      end
      admin_menu_add_menu("content", {icon: "copy", title: t('admin.sidebar.content'), url: "", items: items}) if items.present?
    #end

    admin_menu_add_menu("media", {icon: "picture-o", title: t('admin.sidebar.media'), url: admin_media_path}) if can? :manager, :media
    admin_menu_add_menu("comments", {icon: "comments", title: t('admin.sidebar.comments'), url: admin_comments_path}) if can? :manager, :comments

    items = []
    items << {icon: "desktop", title: t('admin.sidebar.themes'), url: admin_appearances_themes_path} if can? :manager, :themes
    items << {icon: "archive", title: t('admin.sidebar.widgets'), url: admin_appearances_widgets_main_index_path} if can? :manager, :widgets
    items << {icon: "list", title: t('admin.sidebar.menus'), url: admin_appearances_nav_menus_menu_path} if can? :manager, :nav_menu
    admin_menu_add_menu("appearance", {icon: "paint-brush", title: t('admin.sidebar.appearance'), url: "", items: items}) if items.present?


    admin_menu_add_menu("plugins", {icon: "plug", title: "#{t('admin.sidebar.plugins')} <div class='informer informer-info'>#{PluginRoutes.all_plugins.size}</div>", url: admin_plugins_path}) if can? :manager, :plugins

    if can? :manager, :users
      items = []
      items << {icon: "list", title: t('admin.users.all_users'), url: admin_users_path}
      items << {icon: "plus", title: t('admin.users.add_user'), url: new_admin_user_path}
      items << {icon: "group", title: t('admin.users.user_roles'), url: admin_user_roles_path}
      admin_menu_add_menu("users", {icon: "users", title: t('admin.sidebar.users'), url: "", items: items})
    end

    if can? :manager, :settings
      items = []
      items << {icon: "desktop", title: t('admin.sidebar.general_site'), url: admin_settings_site_path}
      items << {icon: "cog", title: t('admin.sidebar.sites'), url: admin_settings_sites_path} if current_site.manage_sites?
      items << {icon: "files-o", title: t('admin.sidebar.contents_type'), url: admin_settings_post_types_path}
      items << {icon: "cog", title: t('admin.sidebar.custom_fields'), url: admin_settings_custom_fields_path}
      items << {icon: "language", title: t('admin.sidebar.languages'), url: admin_settings_languages_path}
      admin_menu_add_menu("settings", {icon: "cogs", title: t('admin.sidebar.settings'), url: "", items: items})
    end

  end

  # add menu item to admin menu at the the end
  # key: key for menu
  # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
  # - icon: font-awesome icon (it is already included "fa fa-")
  # - title: title for the menu
  # - url: url for the menu
  # - items: is an recursive array of the menus without a key
  def admin_menu_add_menu(key, menu)
    @_admin_menus[key] = menu
  end

  # append sub menu to menu with key = key
  # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
  def admin_menu_append_menu_item(key, menu)
    return unless @_admin_menus[key].present?
    @_admin_menus[key][:items] = [] unless @_admin_menus[key].has_key?(:items)
    @_admin_menus[key][:items] << menu
  end

  # prepend sub menu to menu with key = key
  # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
  def admin_menu_prepend_menu_item(key, menu)
    return unless @_admin_menus[key].present?
    @_admin_menus[key][:items] = [] unless @_admin_menus[key].has_key?(:items)
    @_admin_menus[key][:items] = [menu] + @_admin_menus[key][:items]
  end

  # add menu before menu with key = key_target
  # key_menu: key for menu
  # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
  def admin_menu_insert_menu_before(key_target, key_menu, menu)
    res = {}
    @_admin_menus.each do |key, val|
      res[key_menu] = menu if key == key_target
      res[key] = val
    end
    @_admin_menus = res
  end

  # add menu after menu with key = key_target
  # key_menu: key for menu
  # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
  def admin_menu_insert_menu_after(key_target, key_menu, menu)
    res = {}
    @_admin_menus.each do |key, val|
      res[key] = val
      res[key_menu] = menu if key == key_target
    end
    @_admin_menus = res
  end

  # draw admin menu as html
  def admin_menu_draw
    res= []
    @_tmp_menu_parents = []
    menus = _get_url_current
    menus.each do |menu|
      res << "<li data-key='#{menu[:key]}' class='#{"xn-openable" if menu.has_key?(:items)} #{'active' if is_active_menu(menu[:key])}'>
        <a href='#{menu[:url]}'><span class='fa fa-#{menu[:icon]}'></span> <span class='xn-text'>#{menu[:title]}</span></a>
        #{_admin_menu_draw(menu[:items]) if menu.has_key?(:items)}
      </li>"
    end
    _admin_menu_draw_active
    res.join
  end

  private

  def _get_url_current
    menus = @_admin_menus.map{|key, menu|  menu[:key] = key; menu}
    c_site = site_current_url.sub("https://", "http://")
    current_path = "/#{c_site.split(root_url).last}"
    current_path_array = current_path.split('/')
    a_size = current_path_array.size

    (0..a_size).each do |i|
      resp = _search_in_menus(menus, current_path_array[0..a_size-i].join('/'))
      bool = resp[:bool]
      menus = resp[:menus]
      break if bool
    end
    menus
  end

  def is_active_menu(key)
    @_tmp_menu_parents.map{|item| item[:key] == key}.include?(true)
  end

  def _search_in_menus(menus, _url, parent_index = 0)
    bool = false
    menus.each_with_index do |menu, index_menu|
      menu[:key] = "#{parent_index}__#{rand(999...99999)}" if menu[:key].nil?
      url = menu[:url].to_s.sub("https://", "http://")
      url_path = url
      url_path = "/#{url.split(root_url).last}" if url.start_with?("http://")
      bool = url_path == _url
      if menu.has_key?(:items)
        resp = _search_in_menus(menu[:items], _url, parent_index + 1)
        bool = bool || resp[:bool]
        menu[:items] = resp[:menus]
      end
      if bool
        @_tmp_menu_parents[parent_index] = {url: menu[:url], title: menu[:title], key: menu[:key]}
        break
      end
    end
    {menus: menus, bool: bool}
  end

  def _admin_menu_draw(items)
    res = []
    res  << "<ul>"
    items.each do |item|
      res  << "<li class='#{"xn-openable" if item.has_key?(:items)} #{'active' if is_active_menu(item[:key])}'>
                <a href='#{item[:url]}'><span class='fa fa-#{item[:icon]}'></span> #{item[:title]}</a>
                #{_admin_menu_draw(item[:items]) if item.has_key?(:items)}
              </li>"
    end
    res  << "</ul>"
    res.join
  end

  def _admin_menu_draw_active
    bread = []
    @_tmp_menu_parents.each do |item|
      bread << [ActionView::Base.full_sanitizer.sanitize(item[:title]), item[:url]] if item.present?
    end
    @_admin_breadcrumb = [[t('admin.sidebar.dashboard'), admin_dashboard_path]] + bread + @_admin_breadcrumb
  end

end