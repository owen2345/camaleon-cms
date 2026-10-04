# Refuse a custom-field group number that the value row cannot store

## Why

`CamaleonCms::CustomFieldsRead#set_field_values` takes each field's `group_number` from the request
with a lower bound only (`[values[:group_number].to_i, 0].max`), and `cama_permitted_field_options`
permits it as any scalar. The column is a 4-byte integer on PostgreSQL and MySQL.

- A number above 2147483647 raises `ActiveModel::RangeError` at `row.save!`. The request is a 500.
- A JSON body with `"group_number": true` or `false` raises `NoMethodError` on `to_i`. The request is
  a 500. A file sent as the group number does the same.
- `AdminController` rescues `ActiveRecord::RecordInvalid` for a value row, not these two errors.

`custom-field-value-filtering` says that an authenticated caller MUST NOT turn a malformed
field-options param into a 500. The defect is present since 2.9.1.

## What Changes

- `CamaleonCms::CustomFieldsRelationship` validates `group_number`: an integer from 0 to 2147483647.
  The validation reads the value before the integer cast. It runs on a new row, and on a stored row
  only when the number changes. A nil group number passes.
- `set_field_values` gives the group number to the row as the request sent it. An absent or empty
  group number is still group 0. The lower clamp and the `to_i` call go.
- An admin save that sends a refused group number redirects back with a flash error that names the
  field. The stored values stay, because the save runs in a transaction.
- The row refuses a group number text with a broken encoding, or in an encoding that is not
  ASCII-compatible (UTF-16). The integer type of Rails raises its own error for such a text, so the
  group number has its own integer type. The type reads the text as no number, and the validation
  refuses the text. A lookup with such a text finds no row. A save that skips the validation stops
  with the same refusal.
- `set_field_value` and `set_field_values` open a savepoint inside a transaction of the caller. A
  refusal that the caller rescues there rolls back the delete of the stored values.
- **Behavior change:** `set_field_values` refuses a negative group number and a text that is not
  digits. Before, it stored a negative number in group 0 and read a text with `to_i` (`'abc'` was
  group 0, `'1abc'` was group 1). `set_field_value` refuses a negative group number. Before, it
  stored the number.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: a value row refuses a group number that is not an integer in the
  range of the column, on each write path.

## Impact

- `app/models/camaleon_cms/custom_fields_relationship.rb` (the validation),
  `app/models/concerns/camaleon_cms/custom_fields_read.rb` (the hand-off),
  `config/locales/camaleon_cms/admin/*.yml` (the message, in each admin language).
- Specs: examples in `spec/requests/security/field_options_non_hash_param_spec.rb` and a new
  `spec/models/custom_field_value_group_number_spec.rb`.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers about the refusal.
- Ecosystem: `camaleon_export_import` passes an exported row's group number to `set_field_value`, an
  integer or nil. Both pass. `docs/ai/ecosystem.md` records the survey.
