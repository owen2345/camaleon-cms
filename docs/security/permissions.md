# Permissions

Camaleon CMS defines role permissions in two families, both rendered in the User Roles form in the admin UI so site owners can toggle them per-role:

- **Manager permissions** — `CamaleonCms::UserRole::ROLES[:manager]`, stored in a role's `_manager_<site_id>` meta, and site-wide in scope. They become
  abilities through `Ability#define_manage_rules`, which grants `can :manage, <key>` for any key present and truthy in that meta. Checked as
  `can?(:manage, :key)`.
- **Post-type permissions** — `CamaleonCms::UserRole::ROLES[:post_type]`, stored in `_post_type_<site_id>`, and scoped to a list of post type IDs.
  Checked by passing a concrete post type, e.g. `can?(:post_content_unfiltered_html, post_type)`.

Users with the `admin` role satisfy every check through `can :manage, :all` in the Ability class, independently of role meta.

## Manager permissions

- `custom_fields` — Controls who can create/update Custom Field Groups and Custom Fields (write-time permission). This is a manager-level permission
  and should be granted only to trusted users. The permission is checked at write-time by the admin controller so that only permitted roles can
  persist custom field definitions that may contain advanced behavior.
- `contact_form_unfiltered_html` — Permits storing raw, unsanitized HTML in the bundled contact-form plugin's markup settings. See
  [Security: Unfiltered HTML](#security-unfiltered-html) below.

Where enforcement happens
- Write-time enforcement: `CamaleonCms::Admin::Settings::CustomFieldsController` uses CanCan (`authorize! :manage, :custom_fields`) to require the
  `custom_fields` manager permission for create/update/destroy actions. This prevents users without the permission from saving Custom Field Groups
  or fields.
- Render-time behavior: certain field types (notably the `select_eval` field) evaluate stored data when rendering. The project maintains render-time
  behavior for backward compatibility, but write-time restrictions are the primary control: only users with the `custom_fields` permission can create
  or modify fields that might include executable commands. If you need a more restrictive runtime policy, consider auditing/clearing any stored
  `select_eval` commands in the database.

### Security: select_eval Custom Field Type

The `select_eval` custom field type is **restricted due to security concerns** as it can execute arbitrary Ruby code. Starting from version 2.9.2, explicit permission is required to create or modify `select_eval` fields.

**For Administrators:**
- Users with the 'admin' role automatically have full access to all custom field types including `select_eval`
  - This access is granted through `can :manage, :all` in the Ability class, not through role meta
  - Note: The Admin role's "Select Eval" checkbox in the UI will remain unchecked (this is expected behavior)
- Client users are restricted by default

**For Custom Roles:**

To grant `select_eval` permission to a non-admin role:

```ruby
# Via Rails console or application code
role = site.user_roles.find_by(slug: 'editor')
current_meta = role.get_meta("_manager_#{site.id}", {})
role.set_meta("_manager_#{site.id}", current_meta.merge(select_eval: 1))
```

**Via Admin UI:**
1. Navigate to Settings → User Roles
2. Edit the desired role
3. Check the "Select Eval" permission under Manager Permissions
4. Save the role

**Security Implications:**

⚠️ **WARNING**: The `select_eval` field type can execute arbitrary Ruby code. Only grant this permission to **fully trusted users** who understand the security implications.

Example of dangerous usage:
```ruby
# A malicious select_eval command could do:
`rm -rf /` # System command execution
User.destroy_all # Database destruction
ENV['SECRET_KEY_BASE'] # Access to sensitive data
```

**Best Practices:**
- Only grant `select_eval` permission to site administrators or developers
- Regularly audit users with this permission
- Consider removing `select_eval` fields from production sites if not actively needed
- Use alternative field types (select, radio, checkbox) when possible

**For Existing Installations:**

If upgrading from a version prior to 2.9.2, you can use this rake task to ensure admin roles have the `select_eval` permission:

```bash
# Run from your application root
bundle exec rake camaleon_cms:backfill_select_eval_permission
# This task does NOT grant new permissions to admins (they already have all permissions by design via `can :manage, :all`).
# It only corrects the display of the select_eval checkbox for admin roles in the UI, so it appears enabled as expected.
```

This task is idempotent and safe to run multiple times.

**Note:** Custom roles (e.g., 'editor', 'contributor') will need manual permission grants via Rails console or the Admin UI if they require `select_eval` access.

**Background Jobs & Console Usage:**

When creating `select_eval` fields from background jobs or Rails console, you must set the user context:

```ruby
# In a background job or console
user = User.find_by(username: 'admin')
site = Site.first

CurrentRequest.user = user
CurrentRequest.site = site

# Now you can create select_eval fields
group.add_field({ name: 'My Field', slug: 'my_field' }, 
                { field_key: 'select_eval', command: 'my_command' })

# Clean up
CurrentRequest.reset
```

Backfilling existing roles
- If you are upgrading an existing installation to `2.9.2`, see the [migration guide](../upgrading-to-2.9.2.md) for the one-off backfill task and rollout steps.

Security notes
- The `custom_fields` manager permission can allow storing code-like commands (e.g., `select_eval`) 
- Treat `custom_fields` as a high-privilege permission — grant it only to trusted administrators. If you inherit a
  database with pre-existing `select_eval` fields, audit their contents before granting the permission widely

## Security: Unfiltered HTML

Camaleon sanitizes user-submitted HTML on save, and two permissions exempt a role from that sanitization. **They are different permissions with
similar names**, they live in different families, and holding one does not grant the other. Both are introduced in 2.9.3.

| | `post_content_unfiltered_html` | `contact_form_unfiltered_html` |
|---|---|---|
| Family | post-type (`ROLES[:post_type]`) | manager (`ROLES[:manager]`) |
| Role meta | `_post_type_<site_id>` | `_manager_<site_id>` |
| Scope | per post type | all contact forms on the site |
| Checked as | `can?(:post_content_unfiltered_html, post_type)` | `can?(:manage, :contact_form_unfiltered_html)` |
| Exempts | `Post#content` | contact-form `previous_html`, `after_html`, `template`, `field_attributes` |
| Introduced in | [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) | 2.9.3 |

⚠️ **WARNING**: both permissions let a role store markup that is later rendered without escaping — including `<script>`. Because the admin panel is
served from the same origin as the public site, script stored by a holder of either permission executes with the session of any administrator who
views the affected page. Grant them only to users you would be willing to make administrators.

### `post_content_unfiltered_html` — raw HTML in post content

Without this permission, `Post#content` is sanitized at save time with `CamaleonRecord.cama_sanitize_translatable`, which strips `<script>`,
`<iframe>`, event-handler attributes such as `onerror`/`onload`, and `javascript:` URLs, while preserving ordinary formatting. With it, content is
stored exactly as submitted.

The permission is granted per post type, so a role may hold it for one post type and not another.

**Defaults:** the `admin` role satisfies the check through `can :manage, :all`. The default `editor` role is explicitly excluded from it during role
seeding — `site_default_settings.rb` skips this key when granting every other post-type permission — so upgrading does not widen anyone's trust.

### `contact_form_unfiltered_html` — raw HTML in contact-form settings

Covers the four contact-form values that are rendered unescaped by design: `previous_html` and `after_html` (the markup wrapping a form), each field's
`template`, and `field_attributes`. Without the permission those four are sanitized when the form is saved; with it they are stored unchanged.

It affects **only** these four values. Every other contact-form value — field labels, default values, option labels, CSS classes, and anything a
visitor submits — is always escaped when rendered, and no permission changes that.

The grant is deliberately scoped to contact forms rather than to raw HTML in general. A future feature needing its own escape hatch will introduce its
own permission, so enabling this one never silently authorizes a surface you did not intend.

**Defaults:** the `admin` role receives it during seeding, along with every other manager key. The default `editor` and `contributor` roles never
receive manager meta at all, and `client` receives an empty set, so no non-admin role holds it after an upgrade.

### Granting to a custom role

Via the Admin UI:

1. Navigate to Settings → User Roles
2. Edit the desired role
3. For site-wide raw HTML, check **Allow unfiltered HTML** under Manager Permissions
4. For raw HTML in post content, check the same-named permission under the relevant post type
5. Save the role

Via the Rails console:

```ruby
site = CamaleonCms::Site.first
role = site.user_roles.find_by(slug: 'editor')

# Manager family — contact-form markup settings, all forms on the site
manager_meta = role.get_meta("_manager_#{site.id}", {})
role.set_meta("_manager_#{site.id}", manager_meta.merge(contact_form_unfiltered_html: 1))

# Post-type family — per post type, for Post#content
post_type = site.post_types.find_by(slug: 'post')
pt_meta = role.get_meta("_post_type_#{site.id}", {})
pt_meta[:post_content_unfiltered_html] = (pt_meta[:post_content_unfiltered_html] || []) + [post_type.id]
role.set_meta("_post_type_#{site.id}", pt_meta)
```

As with `select_eval`, the Admin role's checkboxes may appear unchecked in the UI even though the permission is effective — admin access comes from
`can :manage, :all`, not from role meta.

### Background jobs and console usage

Both checks read the acting user and site from `CurrentRequest` and **fail closed**: when either is missing, content is sanitized regardless of the
role's permissions. Saves from background jobs, rake tasks, or the console therefore sanitize by default. To save raw HTML from those contexts, set
the request context first, as shown in the `select_eval` section above:

```ruby
CurrentRequest.user = CamaleonCms::User.find_by(username: 'admin')
CurrentRequest.site = CamaleonCms::Site.first
# ... perform the save ...
CurrentRequest.reset
```

### Auditing

To find roles holding either permission:

```ruby
CamaleonCms::Site.all.each do |site|
  site.user_roles.each do |role|
    manager = role.get_meta("_manager_#{site.id}", {})
    post_type = role.get_meta("_post_type_#{site.id}", {})
    puts "#{site.name}/#{role.slug}: manager=#{manager[:contact_form_unfiltered_html].inspect} " \
         "post_type=#{post_type[:post_content_unfiltered_html].inspect}"
  end
end
```

Neither permission sanitizes retroactively. Revoking a role's access stops future raw saves but leaves previously stored markup untouched — audit
existing post content and contact-form settings after revoking.
