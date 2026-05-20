# rubocop:disable Metrics/AbcSize
module CamaleonCms
  module RuntimeAdminMenuConcern
    extend ActiveSupport::Concern

    def admin_menus_add_commons
      admin_menu_add_menu(
        'dashboard',
        { icon: 'dashboard', title: t('camaleon_cms.admin.sidebar.dashboard'), url: cama_admin_dashboard_path }
      )

      items = []
      current_site.post_types.eager_load(:metas).visible_menu.find_each do |pt|
        pt = pt.decorate
        items_i = []
        if can? :posts, pt
          items_i << { icon: 'list', title: t('camaleon_cms.admin.post_type.all').to_s,
                       url: cama_admin_post_type_posts_path(pt.id) }
        end
        if can? :create_post, pt
          items_i << { icon: 'plus', title: t('camaleon_cms.admin.post_type.add_new', type_title: pt.the_title).to_s,
                       url: new_cama_admin_post_type_post_path(pt.id) }
        end
        if pt.manage_categories? && (can? :categories, pt)
          items_i << { icon: 'folder-open', title: t('camaleon_cms.admin.post_type.categories'),
                       url: cama_admin_post_type_categories_path(pt.id) }
        end
        if pt.manage_tags? && (can? :post_tags, pt)
          items_i << { icon: 'tags', title: t('camaleon_cms.admin.post_type.tags'),
                       url: cama_admin_post_type_post_tags_path(pt.id) }
        end
        if items_i.present?
          items << { icon: pt.get_option('icon', 'copy'), title: pt.the_title, url: '', items: items_i }
        end
      end

      if items.present?
        admin_menu_add_menu(
          'content',
          {
            icon: 'database', title: t('camaleon_cms.admin.sidebar.contents'), url: '', items: items,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.content')}' data-position='right' data-wait='600'"
          }
        )
      end

      if can? :manage, :media
        admin_menu_add_menu(
          'media',
          {
            icon: 'picture-o', title: t('camaleon_cms.admin.sidebar.media'), url: cama_admin_media_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.media')}' data-position='right'"
          }
        )
      end
      if can? :manage, :comments
        admin_menu_add_menu(
          'comments',
          {
            icon: 'comments', title: t('camaleon_cms.admin.sidebar.comments'), url: cama_admin_comments_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.comments')}' data-position='right'"
          }
        )
      end

      items = []
      if can? :manage, :themes
        items << {
          icon: 'desktop', title: t('camaleon_cms.admin.sidebar.themes'), url: cama_admin_appearances_themes_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.themes')}' data-position='right'"
        }
      end
      if can? :manage, :widgets
        items << {
          icon: 'archive', title: t('camaleon_cms.admin.sidebar.widgets'),
          url: cama_admin_appearances_widgets_main_index_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.widgets')}' data-position='right'"
        }
      end
      if can? :manage, :nav_menu
        intro_menus_data =
          t('camaleon_cms.admin.intro.menus', image: helpers.asset_path('camaleon_cms/admin/intro/menus.png'))
        items << {
          icon: 'list', title: t('camaleon_cms.admin.sidebar.menus'), url: cama_admin_appearances_nav_menus_path,
          datas: "data-intro='#{intro_menus_data}' data-position='right'"
        }
      end
      if can? :manage, :shortcodes
        items << {
          icon: 'code', title: t('camaleon_cms.admin.sidebar.shortcodes', default: 'Shortcodes'),
          url: cama_admin_settings_shortcodes_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.shortcodes')}' data-position='right'"
        }
      end
      if items.present?
        admin_menu_add_menu(
          'appearance',
          {
            icon: 'paint-brush', title: t('camaleon_cms.admin.sidebar.appearance'), url: '', items: items,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.appearance')}' data-position='right' data-wait='500'"
          }
        )
      end

      if can? :manage, :plugins
        plugin_count = PluginRoutes.all_plugins.count do |plugin|
          !(plugin[:domain].present? && !plugin[:domain].split(',').include?(current_site.the_slug))
        end
        admin_menu_add_menu(
          'plugins',
          {
            icon: 'plug',
            title: helpers.safe_join([
                                       t('camaleon_cms.admin.sidebar.plugins'),
                                       ' ',
                                       helpers.content_tag(:small, plugin_count, class: 'label label-primary')
                                     ]),
            url: cama_admin_plugins_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.plugins')}' data-position='right'"
          }
        )
      end

      if can? :manage, :users
        items = []
        items << { icon: 'list', title: t('camaleon_cms.admin.users.all_users'), url: cama_admin_users_path }
        items << { icon: 'plus', title: t('camaleon_cms.admin.users.add_user'), url: new_cama_admin_user_path }
        items << { icon: 'group', title: t('camaleon_cms.admin.users.user_roles'), url: cama_admin_user_roles_path }
        admin_menu_add_menu(
          'users',
          {
            icon: 'users', title: t('camaleon_cms.admin.sidebar.users'), url: '', items: items,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.users')}' data-position='right' data-wait='500'"
          }
        )
      end

      items = []
      if can? :manage, :settings
        items << {
          icon: 'desktop', title: t('camaleon_cms.admin.sidebar.general_site'),
          url: cama_admin_settings_site_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.gral_site')}' data-position='right'"
        }
        if current_site.manage_sites?
          items << {
            icon: 'cog', title: t('camaleon_cms.admin.sidebar.sites'),
            url: cama_admin_settings_sites_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.sites')}' data-position='right'"
          }
        end
        items << {
          icon: 'files-o', title: t('camaleon_cms.admin.sidebar.content_groups'),
          url: cama_admin_settings_post_types_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.post_type')}' data-position='right'"
        }
        items << {
          icon: 'cog', title: t('camaleon_cms.admin.sidebar.custom_fields'),
          url: cama_admin_settings_custom_fields_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.custom_fields')}' data-position='right'"
        }
        items << {
          icon: 'language', title: t('camaleon_cms.admin.sidebar.languages'),
          url: cama_admin_settings_languages_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.languages')}' data-position='right'"
        }
      end

      if can? :manage, :theme_settings
        items << {
          icon: 'windows', title: t('camaleon_cms.admin.settings.theme_setting', default: 'Theme Settings'),
          url: cama_admin_settings_theme_path
        }
      end
      return if items.blank?

      admin_menu_add_menu(
        'settings',
        {
          icon: 'cogs', title: t('camaleon_cms.admin.sidebar.settings'), url: '', items: items,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.settings')}' data-position='right' data-wait='500'"
        }
      )
    end

    def admin_menu_add_menu(key, menu)
      CurrentRequest.admin_menu_items ||= {}
      CurrentRequest.admin_menu_items[key] = menu
    end

    def admin_menu_append_menu_item(key, menu)
      CurrentRequest.admin_menu_items ||= {}
      return if CurrentRequest.admin_menu_items[key].blank?

      CurrentRequest.admin_menu_items[key][:items] = [] unless CurrentRequest.admin_menu_items[key].key?(:items)
      CurrentRequest.admin_menu_items[key][:items] << menu
    end

    def admin_menu_prepend_menu_item(key, menu)
      CurrentRequest.admin_menu_items ||= {}
      return if CurrentRequest.admin_menu_items[key].blank?

      CurrentRequest.admin_menu_items[key][:items] = [] unless CurrentRequest.admin_menu_items[key].key?(:items)
      CurrentRequest.admin_menu_items[key][:items] = [menu] + CurrentRequest.admin_menu_items[key][:items]
    end

    def admin_menu_insert_menu_before(key_target, key_menu, menu)
      CurrentRequest.admin_menu_items ||= {}
      res = CurrentRequest.admin_menu_items.each_with_object({}) do |(key, val), hsh|
        hsh[key_menu] = menu if key == key_target
        hsh[key] = val
      end
      CurrentRequest.admin_menu_items = res
    end

    def admin_menu_insert_menu_after(key_target, key_menu, menu)
      CurrentRequest.admin_menu_items ||= {}
      res = CurrentRequest.admin_menu_items.each_with_object({}) do |(key, val), hsh|
        hsh[key] = val
        hsh[key_menu] = menu if key == key_target
      end
      CurrentRequest.admin_menu_items = res
    end

    def cama_comments_get_common_data
      comment_data = {}
      comment_data[:user_id] = cama_current_user.id
      comment_data[:author] = cama_current_user.the_name
      comment_data[:author_email] = cama_current_user.email
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = 'approved'
      comment_data[:agent] = request.user_agent.force_encoding('ISO-8859-1').encode('UTF-8')
      comment_data
    end
  end
end
# rubocop:enable Metrics/AbcSize
