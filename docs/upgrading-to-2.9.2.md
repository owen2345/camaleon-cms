# Upgrading to 2.9.2

Version `2.9.2` introduces a dedicated manager permission for Custom Fields administration.

## What changed

Admin actions for Custom Field Groups and Custom Fields now require the manager-level `custom_fields` permission.

## Who should review this guide

Review these steps when upgrading an existing installation where non-superadmin roles already manage Custom Fields in the admin UI.

## Backfilling existing roles

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

## Recommended rollout

1. Upgrade to `2.9.2`.
2. Run `bundle exec rake camaleon_cms:backfill_custom_fields_permission` if existing roles should keep managing Custom Fields.
3. Review role permissions in the admin UI and remove `custom_fields` from roles that should no longer have that access.
4. Audit any existing `select_eval` field definitions before granting `custom_fields` broadly, since this permission controls who can create or modify fields with advanced behavior.
