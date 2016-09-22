class CamaleonCms::UserRole < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :user_roles) }
  has_many :metas, ->{ where(object_class: 'UserRole')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id

  def roles_post_type
    self.get_meta("_post_type")
  end

  def roles_manager
    self.get_meta("_manager")
  end

  def editable?
      term_group.nil?
  end


  ROLES = {
      post_type: [
          {
              key: 'edit',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_create_or_edit')}",
              color: 'success',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.create_or_edit')}"
          },
          {
              key: 'edit_other',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_edit_other')}",
              color: 'success',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.edit_other')}"
          },
          {
              key: 'edit_publish',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_edit_publish')}",
              color: 'success',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.edit_publish')}"
          },
          {
              key: 'publish',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.publish')}",
              color: 'success',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.publish')}"
          },
          {
              key: 'delete',
              label: "#{I18n.t('camaleon_cms.admin.button.delete')}",
              color: 'danger',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.delete')}"
          },
          {
              key: 'delete_other',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_delete_other')}",
              color: 'danger',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.delete_other')}"
          },
          {
              key: 'delete_publish',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_delete_publish')}",
              color: 'danger',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.delete_publish')}"
          },
          #{
          #    key: 'read_private',
          #    label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_read_private')}",
          #    color: 'info',
          #    description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.read_private')}"
          #},
          {
              key: 'manage_categories',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_manage_categories')}",
              color: 'warning',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.manage_categories')}"
          },
          {
              key: 'manage_tags',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.html_manage_tags')}",
              color: 'warning',
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.manage_tags')}"
          }
      ],
      manager: [
          {
              key: 'media',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.media')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.media')}"
          },
          {
              key: 'comments',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.comments')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.comments')}"
          },
          {
              key: 'themes',
              label: "#{I18n.t('camaleon_cms.admin.users.roles_values.themes')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.themes')}"
          },
          {
              key: 'widgets',
              label: "#{I18n.t('camaleon_cms.admin.sidebar.widgets')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.widgets')}"
          },
          {
              key: 'nav_menu',
              label: "#{I18n.t('camaleon_cms.admin.sidebar.menus')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.menus')}"
          },
          {
              key: 'plugins',
              label: "#{I18n.t('camaleon_cms.admin.sidebar.plugins')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.plugins')}"
          },
          {
              key: 'users',
              label: "#{I18n.t('camaleon_cms.admin.sidebar.users')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.users')}"
          },
          {
              key: 'settings',
              label: "#{I18n.t('camaleon_cms.admin.sidebar.settings')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.settings')}"
          },
          {
              key: 'theme_settings',
              label: "#{I18n.t('camaleon_cms.admin.settings.theme_setting', default: 'Theme Settings')}",
              description: "#{I18n.t('camaleon_cms.admin.users.tool_tip.themes')}"
          }
      ]
  }
end
