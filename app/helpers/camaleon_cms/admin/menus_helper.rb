module CamaleonCms
  module Admin
    module MenusHelper
      include CamaleonCms::Admin::BreadcrumbHelper

      def admin_menus_add_commons
        admin_menu_add_menu('dashboard',
                            { icon: 'dashboard', title: t('camaleon_cms.admin.sidebar.dashboard'),
                              url: cama_admin_dashboard_path })
        items = []

        current_site.post_types.eager_load(:metas).visible_menu.all.each do |pt|
          pt = pt.decorate
          items_i = []
          if can? :posts,
                  pt
            items_i << { icon: 'list', title: t('camaleon_cms.admin.post_type.all').to_s,
                         url: cama_admin_post_type_posts_path(pt.id) }
          end
          if can? :create_post,
                  pt
            items_i << { icon: 'plus', title: t('camaleon_cms.admin.post_type.add_new', type_title: pt.the_title).to_s,
                         url: new_cama_admin_post_type_post_path(pt.id) }
          end
          if pt.manage_categories? && (can? :categories,
                                            pt)
            items_i << { icon: 'folder-open', title: t('camaleon_cms.admin.post_type.categories'),
                         url: cama_admin_post_type_categories_path(pt.id) }
          end
          if pt.manage_tags? && (can? :post_tags,
                                      pt)
            items_i << { icon: 'tags', title: t('camaleon_cms.admin.post_type.tags'),
                         url: cama_admin_post_type_post_tags_path(pt.id) }
          end
          if items_i.present?
            items << { icon: pt.get_option('icon', 'copy'), title: pt.the_title, url: '', items: items_i }
          end
        end
        if items.present?
          admin_menu_add_menu('content',
                              { icon: 'database', title: t('camaleon_cms.admin.sidebar.contents'), url: '', items: items,
                                datas: "data-intro='#{t('camaleon_cms.admin.intro.content')}' data-position='right' data-wait='600'" })
        end
        # end

        if can? :manage,
                :media
          admin_menu_add_menu('media',
                              { icon: 'picture-o', title: t('camaleon_cms.admin.sidebar.media'), url: cama_admin_media_path,
                                datas: "data-intro='#{t('camaleon_cms.admin.intro.media')}' data-position='right'" })
        end
        if can? :manage,
                :comments
          admin_menu_add_menu('comments',
                              { icon: 'comments', title: t('camaleon_cms.admin.sidebar.comments'), url: cama_admin_comments_path,
                                datas: "data-intro='#{t('camaleon_cms.admin.intro.comments')}' data-position='right'" })
        end

        items = []
        if can? :manage,
                :themes
          items << { icon: 'desktop', title: t('camaleon_cms.admin.sidebar.themes'), url: cama_admin_appearances_themes_path,
                     datas: "data-intro='#{t('camaleon_cms.admin.intro.themes')}' data-position='right'" }
        end
        if can? :manage,
                :widgets
          items << { icon: 'archive', title: t('camaleon_cms.admin.sidebar.widgets'),
                     url: cama_admin_appearances_widgets_main_index_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.widgets')}' data-position='right'" }
        end
        if can? :manage,
                :nav_menu
          items << { icon: 'list', title: t('camaleon_cms.admin.sidebar.menus'), url: cama_admin_appearances_nav_menus_path,
                     datas: "data-intro='#{t('camaleon_cms.admin.intro.menus', image: view_context.asset_path('camaleon_cms/admin/intro/menus.png'))}' data-position='right'" }
        end
        if can? :manage,
                :shortcodes
          items << { icon: 'code', title: t('camaleon_cms.admin.sidebar.shortcodes', default: 'Shortcodes'),
                     url: cama_admin_settings_shortcodes_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.shortcodes')}' data-position='right'" }
        end
        if items.present?
          admin_menu_add_menu('appearance',
                              { icon: 'paint-brush', title: t('camaleon_cms.admin.sidebar.appearance'), url: '', items: items,
                                datas: "data-intro='#{t('camaleon_cms.admin.intro.appearance')}' data-position='right' data-wait='500'" })
        end

        if can? :manage,
                :plugins
          admin_menu_add_menu('plugins', { icon: 'plug', title: "#{t('camaleon_cms.admin.sidebar.plugins')} <small class='label label-primary'>#{PluginRoutes.all_plugins.clone.delete_if do |plugin|
                                                                                                                                                   plugin[:domain].present? && !plugin[:domain].split(',').include?(current_site.the_slug)
                                                                                                                                                 end.size}</small>", url: cama_admin_plugins_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.plugins')}' data-position='right'" })
        end

        if can? :manage, :users
          items = []
          items << { icon: 'list', title: t('camaleon_cms.admin.users.all_users'), url: cama_admin_users_path }
          items << { icon: 'plus', title: t('camaleon_cms.admin.users.add_user'), url: new_cama_admin_user_path }
          items << { icon: 'group', title: t('camaleon_cms.admin.users.user_roles'), url: cama_admin_user_roles_path }
          admin_menu_add_menu('users',
                              { icon: 'users', title: t('camaleon_cms.admin.sidebar.users'), url: '', items: items,
                                datas: "data-intro='#{t('camaleon_cms.admin.intro.users')}' data-position='right' data-wait='500'" })
        end

        items = []
        if can? :manage, :settings
          items << { icon: 'desktop', title: t('camaleon_cms.admin.sidebar.general_site'),
                     url: cama_admin_settings_site_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.gral_site')}' data-position='right'" }
          if current_site.manage_sites?
            items << { icon: 'cog', title: t('camaleon_cms.admin.sidebar.sites'), url: cama_admin_settings_sites_path,
                       datas: "data-intro='#{t('camaleon_cms.admin.intro.sites')}' data-position='right'" }
          end
          items << { icon: 'files-o', title: t('camaleon_cms.admin.sidebar.content_groups'),
                     url: cama_admin_settings_post_types_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.post_type')}' data-position='right'" }
          items << { icon: 'cog', title: t('camaleon_cms.admin.sidebar.custom_fields'),
                     url: cama_admin_settings_custom_fields_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.custom_fields')}' data-position='right'" }
          items << { icon: 'language', title: t('camaleon_cms.admin.sidebar.languages'),
                     url: cama_admin_settings_languages_path, datas: "data-intro='#{t('camaleon_cms.admin.intro.languages')}' data-position='right'" }
        end

        if can? :manage,
                :theme_settings
          items << { icon: 'windows', title: t('camaleon_cms.admin.settings.theme_setting', default: 'Theme Settings'),
                     url: cama_admin_settings_theme_path }
        end
        return unless items.present?

        admin_menu_add_menu('settings',
                            { icon: 'cogs', title: t('camaleon_cms.admin.sidebar.settings'), url: '', items: items,
                              datas: "data-intro='#{t('camaleon_cms.admin.intro.settings')}' data-position='right' data-wait='500'" })
      end

      # add menu item to admin menu at the the end
      # key: key for menu
      # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
      # - icon: font-awesome icon (it is already included "fa fa-")
      # - title: title for the menu
      # - url: url for the menu
      # - items: is an recursive array of the menus without a key
      # - datas: html data text for this menu item
      def admin_menu_add_menu(key, menu)
        @_admin_menus[key] = menu
      end

      # append sub menu to menu with key = key
      # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
      def admin_menu_append_menu_item(key, menu)
        return unless @_admin_menus[key].present?

        @_admin_menus[key][:items] = [] unless @_admin_menus[key].key?(:items)
        @_admin_menus[key][:items] << menu
      end

      # prepend sub menu to menu with key = key
      # menu: is hash like this: {icon: "dashboard", title: "My title", url: my_path, items: [sub menus]}
      def admin_menu_prepend_menu_item(key, menu)
        return unless @_admin_menus[key].present?

        @_admin_menus[key][:items] = [] unless @_admin_menus[key].key?(:items)
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
        res = []
        @_tmp_menu_parents = []
        menus = _get_url_current
        menus.each do |menu|
          res << "<li data-key='#{menu[:key]}' class='#{if menu.key?(:items)
                                                          'treeview'
                                                        end} #{if is_active_menu(menu[:key])
                                                                 'active'
                                                               end}' #{menu[:datas]}>
        <a href='#{menu[:url]}'><i class='fa fa-#{menu[:icon]}'></i> <span class=''>#{menu[:title]}</span> #{if menu.key?(:items)
                                                                                                               '<i class="fa fa-angle-left pull-right"></i>'
                                                                                                             end}</a>
        #{_admin_menu_draw(menu[:items]) if menu.key?(:items)}
      </li>"
        end
        res.join
      end

      private

      def _get_url_current
        menus = @_admin_menus.map do |key, menu|
          menu[:key] = key
          menu
        end
        current_path = URI(site_current_url).path
        current_path_array = current_path.split('/')
        a_size = current_path_array.size
        (0..a_size).each do |i|
          resp = _search_in_menus(menus, current_path_array[0..a_size - i].join('/'))
          bool = resp[:bool]
          menus = resp[:menus]
          break if bool
        end
        menus
      end

      def is_active_menu(key)
        @_tmp_menu_parents.map { |item| item[:key] == key }.include?(true)
      end

      def _search_in_menus(menus, _url, parent_index = 0)
        bool = false
        menus.each_with_index do |menu, _index_menu|
          menu[:key] = "#{parent_index}__#{rand(999...99_999)}" if menu[:key].nil?
          uri = URI(menu[:url].to_s)
          url_path = uri.path
          url_query = uri.query
          bool = url_path.to_s == _url.to_s && url_path.present?
          # params compare
          if url_query.present?
            bool &&= Rack::Utils.parse_nested_query(url_query.to_s) == Rack::Utils.parse_nested_query(URI(site_current_url).query.to_s)
          end
          if menu.key?(:items)
            resp = _search_in_menus(menu[:items], _url, parent_index + 1)
            bool ||= resp[:bool]
            menu[:items] = resp[:menus]
          end
          if bool
            @_tmp_menu_parents[parent_index] = { url: menu[:url], title: menu[:title], key: menu[:key] }
            break
          end
        end
        { menus: menus, bool: bool }
      end

      def _admin_menu_draw(items)
        res = []
        res << "<ul class='treeview-menu'>"
        items.each_with_index do |item, index|
          res << "<li class='#{if item.key?(:items)
                                 'xn-openable'
                               end} item_#{index + 1} #{if is_active_menu(item[:key])
                                                          'active'
                                                        end}' #{item[:datas]}>
                <a href='#{item[:url]}'><i class='fa fa-#{item[:icon]}'></i> #{item[:title]} #{if item.key?(:items)
                                                                                                 '<i class="fa fa-angle-left pull-right"></i>'
                                                                                               end}</a>
                #{_admin_menu_draw(item[:items]) if item.key?(:items)}
              </li>"
        end
        res << '</ul>'
        res.join
      end
    end
  end
end
