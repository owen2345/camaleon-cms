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
    @_admin_menus.each do |key, menu|
      res << "<li data-key='#{key}' class='#{"xn-openable" if menu.has_key?(:items)} #{_admin_menu_check_url(menu[:url])}'>
        <a href='#{menu[:url]}'><span class='fa fa-#{menu[:icon]}'></span> <span class='xn-text'>#{menu[:title]}</span></a>
        #{_admin_menu_draw(menu[:items]) if menu.has_key?(:items)}
      </li>"
    end

    doc = Nokogiri::HTML.fragment(res.join)
    link_active = doc.css(".active").first
    link_active1 = doc.css(".parent_active1").first
    link_active2 = doc.css(".parent_active2").first
    link_active3 = doc.css(".parent_active3").first
    if link_active.present?
      _admin_menu_draw_active(link_active)
    elsif link_active1.present?
      _admin_menu_draw_active(link_active1)
    elsif link_active2.present?
      _admin_menu_draw_active(link_active2)
    elsif link_active3.present?
      _admin_menu_draw_active(link_active3)
    end
    doc.to_html
  end

  private
  def _admin_menu_draw(items)
    res = []
    res  << "<ul>"
    items.each do |item|
      res  << "<li class='#{"xn-openable" if item.has_key?(:items)} #{_admin_menu_check_url(item[:url])}'>
                <a href='#{item[:url]}'><span class='fa fa-#{item[:icon]}'></span> #{item[:title]}</a>
                #{_admin_menu_draw(item[:items]) if item.has_key?(:items)}
              </li>"
    end
    res  << "</ul>"
    res.join
  end

  def _admin_menu_check_url(url)
    url = url.to_s.sub("https://", "http://")

    c_site = site_current_url.sub("https://", "http://")
    current_path = "/#{c_site.split(root_url).last}"

    url_path = url
    url_path = "/#{url.split(root_url).last}" if url.start_with?("http://")

    # primary menu
    if c_site == url || current_path == url
      res = "active"
    elsif url_path.split("/").slice(1, 4) == current_path.split("/").slice(1, 4)
      res = "parent_active1"
    elsif url_path.split("/").slice(1, 3) == current_path.split("/").slice(1, 3)
        res = "parent_active2"
    elsif url_path.split("/").slice(1, 2) == current_path.split("/").slice(1, 2)
        res = "parent_active3"
    end
    res

  end

  def _admin_menu_draw_active(link_active)
    a = link_active.children.search("a").first
    bread = []
    bread << [a.content, a["href"]]
    link_active['class'] += " active "
    link_active.ancestors('li').each do |parent|
      parent['class'] += ' active parent-active'
      a = parent.children.search("a").first
      bread << [a.content, a["href"]]
    end
    @_admin_breadcrumb = [[t('admin.sidebar.dashboard'), admin_dashboard_path]] + bread.reverse + @_admin_breadcrumb
  end

end