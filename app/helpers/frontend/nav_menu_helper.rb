module Frontend::NavMenuHelper
  # draw nav menu as html list
  # key: slug for nav menu
  # to register this, go to admin -> appearance -> menus
  # (DEPRECATED)
  def get_nav_menu(key = 'main_menu', class_name = "navigation")
    return draw_menu({menu_slug: key, container_class: class_name})

    html = "<ul class='#{class_name}'>#{_get_nav_menu(key, class_name)} #{front_editor_link(admin_appearances_nav_menus_menu_url(slug: key)) rescue ""}</ul>"
    doc = Nokogiri::HTML.fragment(html)
    link_active = doc.css("a[href='#{site_current_path}']").first
    if link_active.present?
      link_active_parent = link_active.parent
      link_active_parent['class'] += ' active'
      link_active_parent.ancestors('li').each do |parent|
        parent['class'] += ' parent-active'
      end
      html = doc.to_html
    end
    html
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
    html = "<#{args[:container]} class='#{args[:container_class]}' id='#{args[:container_id]}'>#{args[:container_prepend]}{__}#{front_editor_link(admin_appearances_nav_menus_menu_url(slug: nav_menu.slug)) rescue ""}#{args[:container_append]}</#{args[:container]}>"
    if nav_menu.present?
      html = html.sub("{__}", _menu_draw_items(args, nav_menu.children))
    else
      html = html.sub("{__}", "")
    end
    html
  end

  # draw menu items
  def _menu_draw_items(args, nav_menu, level = 0)
    html = ""
    _args = args.dup
    parent_current = false
    index = 0
    nav_menu.eager_load(:metas).each do |nav_menu_item|
      data_nav_item = _get_link_nav_menu(nav_menu_item)
      next if data_nav_item == false
      _is_current = site_current_path == data_nav_item[:link] || site_current_path == data_nav_item[:link].sub(".html", "")
      has_children = nav_menu_item.have_children? && (args[:levels] == -1 || (args[:levels] != -1 && level <= args[:levels]))
      r = { menu_item: nav_menu_item, link: data_nav_item, level: level, settings: _args, has_children: has_children, link_attrs: '', index: index}; args[:callback_item].call(r);
      _args = r[:settings]

      if has_children
        html_children, current_children = _menu_draw_items(args, nav_menu_item.children, level + 1)
      else
        html_children, current_children = "", false
      end
      parent_current = true if _is_current || current_children

      html += "<#{_args[:item_container]} class='#{_args[:item_class]} #{_args[:item_class_parent] if has_children} #{"#{_args[:item_current]}" if _is_current} #{"current-menu-ancestor" if current_children }'>#{_args[:link_before]}
                <a #{r[:link_attrs]} href='#{data_nav_item[:link]}' class='#{args[:link_current] if _is_current} #{_args[:link_class_parent] if has_children} #{_args[:link_class]}' >#{_args[:before]}#{data_nav_item[:name]}#{_args[:after]}</a> #{_args[:link_after]}
                #{ html_children }
              </#{_args[:item_container]}>"
      index += 1
    end

    if level == 0
      html
    else
      html = "<#{_args[:sub_container]} class='#{_args[:sub_class]} #{"parent-#{args[:item_current]}" if parent_current} level-#{level}'>#{html}</#{_args[:sub_container]}>"
      [html, parent_current]
    end
  end

  # check if menu is the current menu
  def is_current_menu?(menu_item)
    r = _get_link_nav_menu(menu_item)
    site_current_path == r[:link] || site_current_path.sub(".html", "") == r[:link].sub(".html", "") if r.present?
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
          post = Post.find(nav_menu_item.get_option('object_id')).decorate
          return false unless post.can_visit?
          {link: post.the_url(as_path: true), name: post.the_title, type_menu: type_menu}
        when 'category'
          category = Category.find(nav_menu_item.get_option('object_id')).decorate
          {link: category.the_url(as_path: true), name: category.the_title, type_menu: type_menu}
        when 'post_tag'
          post_tag = PostTag.find(nav_menu_item.get_option('object_id')).decorate
          {link: post_tag.the_url(as_path: true), name: post_tag.the_title, type_menu: type_menu}
        when 'post_type'
          post_type = PostType.find(nav_menu_item.get_option('object_id')).decorate
          {link: post_type.the_url(as_path: true), name: post_type.the_title, type_menu: type_menu}
        when 'external'
          r = {link: nav_menu_item.get_option('object_id'), name: nav_menu_item.name.to_s.translate, type_menu: type_menu}
          r[:link] = url_to_fixed("root_url") if r[:link] == "root_url"
          r
        else
          false
      end
    rescue
      false
    end
  end
end
