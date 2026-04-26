# Upgrading to 2.9.2

Version `2.9.2` introduces two changes:

1. A dedicated manager permission for Custom Fields administration.
2. A security fix for the MediaController requiring consistent authorization across all endpoints.

## Custom Fields Permission Change

Admin actions for Custom Field Groups and Custom Fields now require the manager-level `custom_fields` permission.

For details on select_eval migration and user-context requirements, see [docs/MIGRATION_SELECT_EVAL.md](../MIGRATION_SELECT_EVAL.md).

### Who should review this guide

Review these steps when upgrading an existing installation where non-superadmin roles already manage Custom Fields in the admin UI.

### Backfilling existing roles

If you want to preserve that access for existing roles, run the one-off rake task from your app root:

```bash
bundle exec rake camaleon_cms:backfill_custom_fields_permission
```

The task will:

- iterate over existing `CamaleonCms::UserRole` records
- check each role's `_manager_<site_id>` meta
- add `'custom_fields' => 1` when that permission is currently missing
- skip roles that already have the permission
- print progress to stdout

The task is safe to run more than once.

### Recommended rollout

1. Upgrade to `2.9.2`.
2. Run `bundle exec rake camaleon_cms:backfill_custom_fields_permission` if existing roles should keep managing Custom Fields.
3. Review role permissions in the admin UI and remove `custom_fields` from roles that should no longer have that access.
4. Audit any existing `select_eval` field definitions before granting `custom_fields` broadly, since this permission controls who can create or modify fields with advanced behavior.


## MediaController Security Fix (CWE-862)

This version adds consistent authorization checks to all MediaController endpoints. Previously, only the `index` and `ajax` actions verified the `:manage, :media` permission. Other sensitive endpoints (`upload`, `download_private_file`, `crop`, `actions`) only checked user authentication, not authorization.

### What changed

All MediaController endpoints now require the `:manage, :media` permission via a centralized `before_action`:

```ruby
before_action :verify_media_authorization

def verify_media_authorization
  authorize! :manage, :media
end
```

### Impact

Users who previously could access media endpoints by direct URL (bypassing UI restrictions) will now receive a 403 Forbidden response unless their role includes the `media` manager permission.

### Recommended action

Review user roles in the admin UI (`/admin/user_roles`) and ensure any role that should manage media files has the `media` permission assigned.
