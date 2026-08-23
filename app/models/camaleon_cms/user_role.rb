module CamaleonCms
  class UserRole < CamaleonCms::TermTaxonomy
    normalize_attrs(:description)

    def self.sti_name
      'user_roles'
    end

    after_destroy :set_users_as_cilent

    belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id, optional: true,
                      inverse_of: :user_roles_rel

    def roles_post_type
      get_meta('_post_type')
    end

    def roles_manager
      get_meta('_manager')
    end

    def editable?
      term_group.nil?
    end

    # Users in a role slugged `admin` are administrators: `User#admin?` tests exactly this, and
    # `Ability#initialize` answers `can :manage, :all` for them and returns before this role's
    # `_post_type_`/`_manager_` metas are read. Those metas therefore describe nothing — every
    # permission is held whatever they say.
    def grants_all_permissions?
      slug == 'admin'
    end

    # Whether the permission checkboxes mean anything. False for the default admin role, which is not
    # editable at all, and false for any other role slugged `admin`, whose permissions cannot be
    # withheld from its users. The editor renders them locked and the controller declines to write
    # them, so the two cannot disagree — and a locked checkbox, which the browser does not submit,
    # can never silently clear what is stored.
    def permissions_editable?
      editable? && !grants_all_permissions?
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
        },
        {
          key: 'post_content_unfiltered_html',
          label: I18n.t('camaleon_cms.admin.users.roles_values.post_content_unfiltered_html',
                        default: 'Allow unfiltered HTML in post content').to_s,
          color: 'danger',
          description: I18n.t('camaleon_cms.admin.users.tool_tip.post_content_unfiltered_html',
                              default: 'Permit users with this role to save raw/unfiltered HTML in post content').to_s
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
          key: 'custom_fields',
          label: I18n.t('camaleon_cms.admin.sidebar.custom_fields', default: 'Custom Fields').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.custom_fields',
                              default: 'Manage custom field groups and fields, including the select_eval type.').to_s
        },
        {
          key: 'select_eval',
          label: I18n.t('camaleon_cms.admin.custom_field.select_eval', default: 'Select Eval').to_s,
          description: I18n.t(
            'camaleon_cms.admin.users.tool_tip.select_eval',
            default: 'Allow toggling and using select_eval custom fields in the admin UI.'
          ).to_s
        },
        {
          key: 'theme_settings',
          label: I18n.t('camaleon_cms.admin.settings.theme_setting', default: 'Theme Settings').to_s,
          description: I18n.t('camaleon_cms.admin.users.tool_tip.themes').to_s
        },
        {
          key: 'contact_form_unfiltered_html',
          label: I18n.t('camaleon_cms.admin.users.roles_values.contact_form_unfiltered_html',
                        default: 'Allow unfiltered HTML in contact forms').to_s,
          color: 'danger',
          description: I18n.t(
            'camaleon_cms.admin.users.tool_tip.contact_form_unfiltered_html',
            default: 'Permit users with this role to save raw/unfiltered HTML anywhere in a contact form: the ' \
                     'markup wrapping a form, field labels, descriptions, templates, CSS classes, default ' \
                     'values, custom attributes, option labels and response messages. Without it, a save ' \
                     'carrying such content is refused rather than cleaned up. Distinct from the per-post-type ' \
                     '"Allow unfiltered HTML in post content" permission.'
          ).to_s
        },
        {
          key: 'media_unfiltered_upload',
          label: I18n.t('camaleon_cms.admin.users.roles_values.media_unfiltered_upload',
                        default: 'Allow unscanned media uploads').to_s,
          color: 'danger',
          description: I18n.t(
            'camaleon_cms.admin.users.tool_tip.media_unfiltered_upload',
            default: 'Permit users with this role to upload files without the malicious-content scan. Without ' \
                     'it, every upload is scanned whatever its source, and a file carrying scripts, event ' \
                     'handlers, blocked elements or blocked URI schemes is refused rather than cleaned up. ' \
                     'Uploaded files are served from the site origin, so this grants the ability to publish ' \
                     'active content there. Site-wide, unlike the per-post-type "Allow unfiltered HTML in post ' \
                     'content" permission.'
          ).to_s
        },
        {
          key: 'content_shortcodes',
          label: I18n.t('camaleon_cms.admin.users.roles_values.content_shortcodes',
                        default: 'Allow shortcodes in content').to_s,
          color: 'danger',
          description: I18n.t(
            'camaleon_cms.admin.users.tool_tip.content_shortcodes',
            default: 'Permit users with this role to publish shortcodes in content that the CMS expands at ' \
                     'render: post content, custom-field values, taxonomy content and widget descriptions. A ' \
                     'shortcode makes theme/plugin code emit arbitrary HTML/JS on the page, which the ' \
                     'content scan cannot judge. Without it, a save carrying a registered shortcode is refused ' \
                     'rather than cleaned up. Site-wide, and an end-run around the per-post-type "Allow ' \
                     'unfiltered HTML in post content" permission.'
          ).to_s
        }
      ]
    }.freeze

    private

    def set_users_as_cilent
      site.users.where(role: slug).update_all(role: 'client') # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
