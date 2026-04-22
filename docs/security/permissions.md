# Permissions (Manager roles)

Camaleon CMS exposes a set of manager permissions that control access to admin surfaces. These manager permissions are defined in
`CamaleonCms::UserRole::ROLES[:manager]` and are rendered in the User Roles form in the admin UI so site owners can toggle them per-role.

- `custom_fields` — Controls who can create/update Custom Field Groups and Custom Fields (write-time permission). This is a manager-level permission
  and should be granted only to trusted users. The permission is checked at write-time by the admin controller so that only permitted roles can
  persist custom field definitions that may contain advanced behavior.

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
