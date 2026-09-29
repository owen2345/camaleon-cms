# Permit list-shaped custom-field values in the shared allow-list

## Why

`CamaleonCms::Admin::CustomFieldsConcern#cama_permitted_field_options` permits each field as
`[:id, :group_number, { values: {} }]`, so `values` passes only as a hash keyed by index. The admin
JavaScript renames each field's `values[]` inputs to `values[<index>]`, except for the checkboxes
field, whose partial opts out (`cama_skip_cf_rename_multiple`) and submits
`field_options[<group>][<slug>][values][]`: a list of scalars. The permit drops it, and
`set_field_values` deletes every stored value before writing, so each admin save of a record with a
checkboxes field (site settings, post type, post and draft, category, post tag, user, nav menu item,
widget assignment, theme, plugins calling the helper) stores nothing for the field and wipes what it
held. The allow-list shipped in 2.9.2, so the field has not saved from the admin since.

## What Changes

- The shared permit accepts `values` as a list of scalars as well as the index-keyed hash. A list is
  stored in the order submitted, as `set_field_values` already does for a list it is handed.
- A list holding anything other than scalars (hashes, nested lists) stays dropped, as today.
- No change to the checkboxes partial, the admin JavaScript, `set_field_values` or any controller.
- `docs/upgrading-to-2.9.5.md` tells upgraders which records to review: the values those saves
  removed are not restored.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-filtering`: the shared permit keeps a permitted slug's values in both shapes
  the admin forms submit, the index-keyed hash and the list of scalars.

## Impact

- `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb` (the permit's filter).
- Specs: a request spec for the checkboxes save (site settings and post), the helper spec.
- Ecosystem: `camaleon-post-clone` PR #3 re-keys the list by index before calling the helper; that
  keeps working and can be dropped once the plugin requires a core release carrying this fix. No
  other surveyed caller changes.
