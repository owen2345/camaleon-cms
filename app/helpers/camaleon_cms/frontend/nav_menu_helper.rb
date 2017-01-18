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
      html = html.sub("{__}", cama_menu_draw_items(args, nav_menu.children.reorder(:term_order)))
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
      data_nav_item = cama_parse_menu_item(nav_menu_item)
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
        html_children, current_children = cama_menu_draw_items(args, nav_menu_item.children.reorder(:term_order), level + 1)
      else
        html_children, current_children = "", false
      end
      parent_current = true if _is_current || current_children

      html += "<#{_args[:item_container]} #{r[:item_container_attrs]} class='#{_args[:item_class]} #{_args[:item_class_parent] if has_children} #{"#{_args[:item_current]}" if _is_current} #{"current-menu-ancestor" if current_children }'>#{_args[:link_before]}
                <a #{r[:link_attrs]} #{" target='#{nav_menu_item.target}'" if nav_menu_item.target.present?} href='#{data_nav_item[:link]}' class='#{args[:link_current] if _is_current} #{_args[:link_class_parent] if has_children} #{_args[:link_class]}' #{"data-toggle='dropdown'" if has_children } >#{_args[:before]}#{data_nav_item[:name]}#{_args[:after]}</a> #{_args[:link_after]}
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

  # filter and parse all menu items visible for current user and adding the flag for current_parent or current_item
  # max_levels: max levels to iterate
  # return an multidimensional array with all items until level 'max_levels'
  # internal_level: ingnore (managed by internal recursion)
  def cama_menu_parse_items(items, max_levels=-1, internal_level=0)
    res, is_current_parent, levels = [], false, [0]
    items.reorder(:term_order).each_with_index do |nav_menu_item, index|
      data_nav_item = cama_parse_menu_item(nav_menu_item)
      next if data_nav_item == false
      _is_current = data_nav_item[:current] || site_current_path == data_nav_item[:link] || site_current_path == data_nav_item[:link].sub(".html", "")
      has_children = nav_menu_item.have_children?
      has_children = false if max_levels > 0 && max_levels == internal_level
      data_nav_item[:label] = data_nav_item[:name]
      data_nav_item[:url] = data_nav_item[:link]
      r = {
          menu_item: nav_menu_item.decorate,
          level: internal_level,
          has_children: has_children,
          index: index,
          current_item: _is_current,
          current_parent: false,
          levels: 0
      }.merge(data_nav_item.except(:current, :name, :link))

      if has_children
        r[:children], _is_current_parent, r[:levels] = cama_menu_parse_items(nav_menu_item.children, max_levels, internal_level + 1)
        if _is_current_parent
          is_current_parent = true
          r[:current_parent] = true
        end
        r[:levels] = r[:levels] + 1
      end
      is_current_parent = true if r[:current_item]
      levels << r[:levels]
      res << r
    end

    if internal_level == 0
      res
    else
      [res, is_current_parent, levels.max]
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


  def cama_parse_menu_item(nav_menu_item, is_from_backend = false)
    type_menu, result = nav_menu_item.kind, false
    begin
      case type_menu
        when 'post'
          post = CamaleonCms::Post.find(nav_menu_item.url).decorate
          if is_from_backend || post.can_visit?
            result = {link: post.the_url(as_path: true), name: post.the_title, type_menu: type_menu, url_edit: post.the_edit_url}
            result[:current] = @cama_visited_post.present? && @cama_visited_post.id == post.id unless is_from_backend
          end
        when 'category'
          category = CamaleonCms::Category.find(nav_menu_item.url).decorate
          result = {link: category.the_url(as_path: true), name: category.the_title, url_edit: category.the_edit_url}
          result[:current] = @cama_visited_category.present? && @cama_visited_category.id == category.id unless is_from_backend
        when 'post_tag'
          post_tag = CamaleonCms::PostTag.find(nav_menu_item.url).decorate
          result = {link: post_tag.the_url(as_path: true), name: post_tag.the_title, url_edit: post_tag.the_edit_url}
          result[:current] = @cama_visited_tag.present? && @cama_visited_tag.id == post_tag.id unless is_from_backend
        when 'post_type'
          post_type = CamaleonCms::PostType.find(nav_menu_item.url).decorate
          result = {link: post_type.the_url(as_path: true), name: post_type.the_title, url_edit: post_type.the_edit_url}
          result[:current] = @cama_visited_post_type.present? && @cama_visited_post_type.id == post_type.id unless is_from_backend
        when 'external'
          result = {link: nav_menu_item.url.to_s.translate, name: nav_menu_item.name.to_s.translate, current: false}
          # permit to customize or mark as current menu
          # _args: (HASH) {menu_item: Model Menu Item, parsed_menu: Parsed Menu }
          #   Sample parsed_menu: {link: "url of the link", name: "Text of the menu", current: Boolean (true => is current menu, false => not current menu item)}
          unless is_from_backend
            result[:link] = cama_root_path if result[:link] == "root_url"
            result[:link] = site_current_path if site_current_path == "#{current_site.the_path}#{result[:link]}"
            result[:current] = result[:link] == site_current_url || result[:link] == site_current_path
            _args = {menu_item: nav_menu_item, parsed_menu: result}; hooks_run("on_external_menu", _args)
            result = _args[:parsed_menu]
          end
        else
          # permit to build custom menu items registered as Custom Menu by hook "nav_menu_custom"
          # sample: def my_parse_custom_menu_item_listener(args);
          #   if args[:menu_item].kind == 'MyModelClass'
          #     my_model = MyModelClass.find(args[:menu_item].url)
          #     res = {name: my_model.name, url_edit: my_model_edit_url(id: my_model.id), link: my_model_public_url(id: my_model.id)}
          #     res[:current] = site_current_path == my_model_public_url(id: my_model.id) unless args[:is_from_backend]
          #     args[:parsed_menu] = res
          #   end
          # end
          hook_args={menu_item: nav_menu_item, parsed_menu: false, is_from_backend: is_from_backend}; hooks_run('parse_custom_menu_item', hook_args)
          result = hook_args[:parsed_menu]
      end
    rescue => e
      Rails.logger.error "Camaleon CMS - Menu Item Not Found => Skipped menu for: #{e.message} (#{nav_menu_item.inspect})".cama_log_style(:red)
    end

    # permit to customize data, like: current, title, ... of parsed menu item or skip menu item by assigning false into :parsed_menu
    unless is_from_backend
      _args = {menu_item: nav_menu_item, parsed_menu: result};  hooks_run("on_render_front_menu_item", _args)
      _args[:parsed_menu]
    else
      result
    end
  end
end
