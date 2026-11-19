# Keep the field values beside a field with a numeric slug

## Why

A custom field can have a slug of digits only, such as `2020`. An admin form posts each field as
`field_options[<index>][<slug>]`, so such a field gives a numeric key with a hash value.
`CamaleonCms::Admin::CustomFieldsConcern#cama_permitted_field_options` gives Rails one nested filter
for all groups. Rails reads a hash with such a key as nested attributes when a nested filter permits
it. Rails then keeps only the numeric keys of the group and drops the other fields. From Rails 7.0,
Rails does not do this when the filter names a numeric key (design, Context).

The post editor shows the field groups of the post type, of the post itself and of its categories. It
gives index 0 to the first instance of each group, so their fields arrive in one `field_options[0]`.
The post save permits only the fields of the post type. A field `2020` of the post itself then
removes the post type fields from the payload:

- On 2.9.2 to 2.9.4, the save removed all custom field values of the post.
- On the current `master`, the save answers "The Post has been updated." and stores no field value.

On Rails 6.1, a registered field with a numeric slug has the same effect in each admin form.

## What Changes

- The shared permit reads the groups and the allowed slugs itself. It gives Rails only one field
  entry at a time, which has fixed keys (`id`, `group_number`, `values`).
- A field with a numeric slug no longer removes the other fields of its group. This holds for a slug
  in the scope of the permit and for a slug outside it, on each supported Rails version.
- A field entry that holds a numeric key with a hash value keeps its `id`, group number and values.
  The permit drops that key, as it drops each other key that it does not know. Before, the entry lost
  its values.
- The permit reports no unpermitted parameter for a group or a slug that it drops. It still reports
  an unknown key inside a field entry (design D3).
- `docs/upgrading-to-2.9.5.md` tells an upgrader which records to review. This release does not
  restore the values that the saves of 2.9.2 to 2.9.4 removed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-filtering`: the shared permit keeps the entries of the allowed slugs of a group
  that holds a numeric key. A field entry keeps its values beside a key that the permit does not
  know.

## Impact

- `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb`: the permit.
- Specs: a new request spec for the post save and the draft save, and examples in the spec of the
  helper.
- `docs/upgrading-to-2.9.5.md` and `CHANGELOG.md`.
- Ecosystem: the result of the helper does not change for a payload that an admin form sends. A
  plugin that calls the helper needs no change.
