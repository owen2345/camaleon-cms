module Themes
  module New
    module CustomHelper
      def theme_custom_settings(_theme)
        # save_theme already persists the submitted field_options through the filtered
        # cama_permitted_field_options('Theme') path and renders the single response, so this
        # hook no longer saves (its old raw save bypassed that filter and its redirect errored).
        render 'themes/new/views/admin/settings' if params[:action_name] == 'settings'
      end

      def theme_custom_on_install_theme(theme)
        unless theme.get_field_groups.where(slug: 'theme_new_fields').any?
          group = theme.add_custom_field_group({ name: 'New theme settings', slug: 'theme_new_fields',
                                                 description: 'new theme' })
          group.add_manual_field({ 'name' => 'Background color', 'slug' => 'theme_custom_bg_color' },
                                 { field_key: 'colorpicker', required: true })
          group.add_manual_field({ 'name' => 'Links color', 'slug' => 'theme_custom_links_color' },
                                 { field_key: 'colorpicker', required: true })
          group.add_manual_field({ 'name' => 'Footer text', 'slug' => 'theme_custom_footer_text' },
                                 { field_key: 'editor', translate: true })
        end

        return if theme.site.nav_menus.where(slug: 'main_menu').any?

        theme.site.nav_menus.create(name: 'Main Menu', slug: 'main_menu')
      end

      def theme_custom_on_uninstall_theme(theme)
        theme.get_field_groups.destroy_all
        theme.destroy
      end
    end
  end
end
