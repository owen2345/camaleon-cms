module CamaleonCms
  class UserRole < CamaleonCms::TermTaxonomy
    after_destroy :set_users_as_cilent

    default_scope { where(taxonomy: :user_roles) }

    belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id, required: false

    def roles_post_type
      get_meta('_post_type')
    end

    def roles_manager
      get_meta('_manager')
    end

    def editable?
      term_group.nil?
    end

    ROLES = {
      post_type: [
        {
          key: 'edit',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_create_or_edit').to_s,
          color: 'success',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.create_or_edit').to_s
        },
        {
          key: 'edit_other',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_edit_other').to_s,
          color: 'success',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.edit_other').to_s
        },
        {
          key: 'edit_publish',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_edit_publish').to_s,
          color: 'success',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.edit_publish').to_s
        },
        {
          key: 'publish',
          label: I18n.t('camaleon_cms.admin.users.roles_values.publish').to_s,
          color: 'success',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.publish').to_s
        },
        {
          key: 'delete',
          label: I18n.t('camaleon_cms.admin.button.delete').to_s,
          color: 'danger',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.delete').to_s
        },
        {
          key: 'delete_other',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_delete_other').to_s,
          color: 'danger',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.delete_other').to_s
        },
        {
          key: 'delete_publish',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_delete_publish').to_s,
          color: 'danger',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.delete_publish').to_s
        },
        # {
        #    key: 'read_private',
        #    label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_read_private')}",
        #    color: 'info',
        #    description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.read_private')}"
        # },
        {
          key: 'manage_categories',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_manage_categories').to_s,
          color: 'warning',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.manage_categories').to_s
        },
        {
          key: 'manage_tags',
          label: I18n.t('camaleon_cms.admin.users.roles_values.html_manage_tags').to_s,
          color: 'warning',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.manage_tags').to_s
        }
      ],
      manager: [
        {
          key: 'media',
          label: I18n.t('camaleon_cms.admin.users.roles_values.media').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.media').to_s
        },
        {
          key: 'comments',
          label: I18n.t('camaleon_cms.admin.users.roles_values.comments').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.comments').to_s
        },
        {
          key: 'themes',
          label: I18n.t('camaleon_cms.admin.users.roles_values.themes').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.themes').to_s
        },
        {
          key: 'widgets',
          label: I18n.t('camaleon_cms.admin.sidebar.widgets').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.widgets').to_s
        },
        {
          key: 'nav_menu',
          label: I18n.t('camaleon_cms.admin.sidebar.menus').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.menus').to_s
        },
        {
          key: 'plugins',
          label: I18n.t('camaleon_cms.admin.sidebar.plugins').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.plugins').to_s
        },
        {
          key: 'users',
          label: I18n.t('camaleon_cms.admin.sidebar.users').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.users').to_s
        },
        {
          key: 'settings',
          label: I18n.t('camaleon_cms.admin.sidebar.settings').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.settings').to_s
        },
        {
          key: 'theme_settings',
          label: I18n.t('camaleon_cms.admin.settings.theme_setting', default: 'Theme Settings').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.themes').to_s
        }
      ]
    }.freeze

    private

    def set_users_as_cilent
      site.users.where(role: slug).update_all(role: 'client')
    end
  end
end
