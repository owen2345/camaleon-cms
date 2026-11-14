# Check the role for each custom field group page

## Why

The custom fields controller named three actions for its role check: `create`, `update` and
`destroy`. That line replaced the role check of the settings controller, which covered each action.
So the other actions had no role check.

A signed-in user with no `custom_fields` permission could change the order of the field groups
through the `reorder` action. The same user could read each field group in the list, in the form and
on the page of a group.

### Triage verdict: legit

`spec/requests/security/custom_field_group_role_check_spec.rb` signs in a Contributor. Before the
fix, the `reorder` request stored a new order, and five read requests gave their page.

## What Changes

- Each action of the custom fields controller checks the `custom_fields` permission, except `list`.
- The `list` action keeps its own check: the right of the user on the post, or on the post type.
- The Settings menu shows its Custom Fields item only to a role with the `custom_fields` permission.
- `docs/upgrading-to-2.9.5.md` and `docs/security/permissions.md` give the change.

## Capabilities

### New Capabilities

- `custom-field-group-access`: a user needs the `custom_fields` permission for each page and each
  write of the custom field groups.

### Modified Capabilities

None.

## Impact

- `app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb`
- `app/controllers/concerns/camaleon_cms/runtime_admin_menu_concern.rb`,
  `app/helpers/camaleon_cms/admin/menus_helper.rb`
- Spec: `spec/requests/security/custom_field_group_role_check_spec.rb`
- `docs/upgrading-to-2.9.5.md`, `docs/security/permissions.md`
- **BREAKING** for a role with no `custom_fields` permission: the list, the form and the page of a
  field group now redirect to the dashboard.
