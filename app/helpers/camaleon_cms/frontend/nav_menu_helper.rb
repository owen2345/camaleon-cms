=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::Frontend::NavMenuHelper
  # draw nav menu as html list
  # key: slug for nav menu
  # to register this, go to admin -> appearance -> menus
  # (DEPRECATED)
  def get_nav_menu(key = 'main_menu', class_name = "navigation")
    draw_menu({menu_slug: key, container_class: class_name})
  end

  # draw menu as an html
  # default configurations is for bootstrap support
  def draw_menu(args = {})
    args_def = {
                menu_slug:        'main_menu', #slug for the menu
                container:        'ul', #type of container for the menu
                container_id:     '', #container id for the menu
                container_class:  'nav navbar-nav nav-menu', #container class for the menu
                item_container:   'li', #type of container for the items
                item_current:     'current-menu-item', #class for current menu item
                item_class:       'menu-item', # class for all menu items
                item_class_parent:"dropdown", # class for all menu items that contain sub items
                sub_container:    'ul', #type of container for sub items
                sub_class:        'dropdown-menu', # class for sub container
                callback_item:    lambda{|args| },
                    # callback executed for each item (args = { menu_item, link, level, settings, has_children, link_attrs = "", index}).
                    #     menu_item: (Object) Menu object
                    #     link: (Hash) link data: {link: '', name: ''}
                    #     level: (Integer) current level
                    #     has_children: (boolean) if this item contain sub menus
                    #     settings: (Hash) menu settings
                    #     index: (Integer) Index Position of this menu
                    #     link_attrs: (String) Here you can add your custom attrs for current link, sample: id='my_id' data-title='#{args[:link][:name]}'
                    #     item_container_attrs: (String) Here you can add your custom attrs for link container.
                    # In settings you can change the values for this item, like after, before, ..:
                    # sample: lambda{|args| args[:settings][:after] = "<span class='caret'></span>" if args[:has_children]; args[:link_attrs] = "id='#{menu_item.id}'";  }
                    # sample: lambda{|args| args[:settings][:before] = "<i class='fa fa-home'></i>" if args[:level] == 0 && args[:index] == 0;  }
                before:           '', # content before link text
                after:            '', # content after link text
                link_current:     'current-link', # class for current menu link
                link_before:      '', # content before link
                link_after:       '', # content after link
                link_class:       'menu_link', # class for all menu links
                link_class_parent:"dropdown-toggle", # class for all menu links that contain sub items
                levels:            -1, # max of levels to recover, -1 => return all levels
                container_prepend:      '', # content prepend for menu container
                container_append:       ''  # content append for menu container
                }

    args = args_def.merge(args)
    nav_menu = current_site.nav_menus.find_by_slug(args[:menu_slug])
    nav_menu = current_site.nav_menus.first unless nav_menu.present?
    html = "<#{args[:container]} class='#{args[:container_class]}' id='#{args[:container_id]}'>#{args[:container_prepend]}{__}#{args[:container_append]}</#{args[:container]}>"
    if nav_menu.present?
      html = html.sub("{__}", cama_menu_draw_items(args, nav_menu.children))
    else
      html = html.sub("{__}", "")
    end
    html
  end

  # draw menu items
  def cama_menu_draw_items(args, nav_menu, level = 0)
    html = ""
    parent_current = false
    index = 0
    nav_menu.eager_load(:metas).each do |nav_menu_item|
      _args = args.dup
      data_nav_item = _get_link_nav_menu(nav_menu_item)
      next if data_nav_item == false
      _is_current = data_nav_item[:current] || site_current_path == data_nav_item[:link] || site_current_path == data_nav_item[:link].sub(".html", "")
      has_children = nav_menu_item.have_children? && (args[:levels] == -1 || (args[:levels] != -1 && level <= args[:levels]))
      r = {
        menu_item: nav_menu_item.decorate,
        link: data_nav_item,
        level: level,
        settings: _args,
        has_children: has_children,
        link_attrs: '',
        item_container_attrs: '',
        index: index
      }
      args[:callback_item].call(r)
      _args = r[:settings]

      if has_children
        html_children, current_children = cama_menu_draw_items(args, nav_menu_item.children, level + 1)
      else
        html_children, current_children = "", false
      end
      parent_current = true if _is_current || current_children

      html += "<#{_args[:item_container]} #{r[:item_container_attrs]} class='#{_args[:item_class]} #{_args[:item_class_parent] if has_children} #{"#{_args[:item_current]}" if _is_current} #{"current-menu-ancestor" if current_children }'>#{_args[:link_before]}
                <a #{r[:link_attrs]} href='#{data_nav_item[:link]}' class='#{args[:link_current] if _is_current} #{_args[:link_class_parent] if has_children} #{_args[:link_class]}' #{"data-toggle='dropdown'" if has_children } >#{_args[:before]}#{data_nav_item[:name]}#{_args[:after]}</a> #{_args[:link_after]}
                #{ html_children }
              </#{_args[:item_container]}>"
      index += 1
    end

    if level == 0
      html
    else
      html = "<#{args[:sub_container]} class='#{args[:sub_class]} #{"parent-#{args[:item_current]}" if parent_current} level-#{level}'>#{html}</#{args[:sub_container]}>"
      [html, parent_current]
    end
  end

  #******************* BREADCRUMBS *******************
  # draw the breadcrumb as html list
  def breadcrumb_draw
    res = []
    @_front_breadcrumb.each_with_index do |item, index|
      if @_front_breadcrumb.size == (index+1) #last menu
        res << "<li class='active'>#{item[0]}</li>"
      else
        res << "<li><a href='#{item[1]}'>#{item[0]}</a></li>"
      end
    end
    res.join("")
  end

  # add breadcrumb item at the end
  # label => label of the link
  # url: url for the link
  def breadcrumb_add(label, url = "", prepend = false)
    if prepend
      @_front_breadcrumb = @_front_breadcrumb.unshift([label, url])
    else
      @_front_breadcrumb << [label, url]
    end
  end


  private
  def _get_link_nav_menu(nav_menu_item)
    type_menu = nav_menu_item.get_option('type')
    begin
      case type_menu
        when 'post'
          post = CamaleonCms::Post.find(nav_menu_item.get_option('object_id')).decorate
          return false unless post.can_visit?
          r = {link: post.the_url(as_path: true), name: post.the_title, type_menu: type_menu, current: @cama_visited_post.present? && @cama_visited_post.id == post.id}
        when 'category'
          category = CamaleonCms::Category.find(nav_menu_item.get_option('object_id')).decorate
          r = {link: category.the_url(as_path: true), name: category.the_title, type_menu: type_menu, current: @cama_visited_category.present? && @cama_visited_category.id == category.id}
        when 'post_tag'
          post_tag = CamaleonCms::PostTag.find(nav_menu_item.get_option('object_id')).decorate
          r = {link: post_tag.the_url(as_path: true), name: post_tag.the_title, type_menu: type_menu, current: @cama_visited_tag.present? && @cama_visited_tag.id == post_tag.id}
        when 'post_type'
          post_type = CamaleonCms::PostType.find(nav_menu_item.get_option('object_id')).decorate
          r = {link: post_type.the_url(as_path: true), name: post_type.the_title, type_menu: type_menu, current: @cama_visited_post_type.present? && @cama_visited_post_type.id == post_type.id}
        when 'external'
          r = {link: nav_menu_item.get_option('object_id', "").to_s.translate, name: nav_menu_item.name.to_s.translate, type_menu: type_menu, current: false}
          r[:link] = cama_root_path if r[:link] == "root_url"
          r[:link] = site_current_path if site_current_path == "#{current_site.the_path}#{r[:link]}"
          r[:current] = r[:link] == site_current_url || r[:link] == site_current_path
          # permit to customize or mark as current menu
          # _args: (HASH) {menu_item: Model Menu Item, parsed_menu: Parsed Menu }
          #   Sample parsed_menu: {link: "url of the link", name: "Text of the menu", type_menu: 'external', current: Boolean (true => is current menu, false => not current menu item)}
          _args = {menu_item: nav_menu_item, parsed_menu: r};  hooks_run("on_external_menu", _args)
          r = _args[:parsed_menu]
          return false if _args[:parsed_menu] == false

        else
          return false
      end
    rescue => e
      puts "-------------------------- menu item error: #{e.message}"
      return false
    end

    # permit to mark as a current menu custom paths
    # sample: @cama_current_menu_path = '/my_section'
    # sample2: @cama_current_menu_path = ['/my_section', '/mi_seccion'] # multi language support
    r[:current] = true if @cama_current_menu_path.present? && !r[:current] && (@cama_current_menu_path.is_a?(String) ? @cama_current_menu_path == r[:link] : @cama_current_menu_path.include?(r[:link]))
    r
  end
end
