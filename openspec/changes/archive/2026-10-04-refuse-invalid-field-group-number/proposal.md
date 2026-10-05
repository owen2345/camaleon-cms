# Validate the group number of a custom-field value

## Why

`CamaleonCms::CustomFieldsRead#set_field_values` takes the `group_number` of each field from the
request with a lower bound only (`[values[:group_number].to_i, 0].max`), and
`cama_permitted_field_options` permits it as any scalar. The column is a 4-byte integer on
PostgreSQL and MySQL.

- A number above 2147483647 raises `ActiveModel::RangeError` at the save. The request is a 500.
  Release 2.2.0 already has this defect.
- A JSON `true` or `false`, or a file, raises `NoMethodError` on `to_i`. The request is a 500. This
  defect is present since 2.9.3, which added the `to_i` call.

`custom-field-value-filtering` says that an authenticated caller MUST NOT turn a malformed
field-options param into a 500.

## What Changes

- `CamaleonCms::CustomFieldsRelationship` validates the group number of a custom-field value. A
  valid group number is nil, an Integer from 0 to 2147483647, or a String of 1 to 16 digits with
  such a number. The validation reads the number before the type cast of Rails. It runs for a new
  value always, and for a stored value only when its group number changes.
- An admin save with an invalid group number redirects back with a flash error that names the
  field. The record keeps its stored values.
- The group number has its own integer type. The type returns nil for a String that Rails cannot
  cast (an invalid encoding, or an encoding such as UTF-16), so that String gets the same error.
  The type keeps the range of a 4-byte integer on each database.
- A copy (`dup`) of a value keeps the group number as the caller gave it, so the copy of an invalid
  value is invalid.
- `set_field_value` and `set_field_values`:
  - They validate the group number also when they get no value to store.
  - They use a savepoint inside a transaction of the caller. When the caller rescues their error
    there and commits, the stored values stay.
  - They reset the `custom_field_values` association of the record after a failed call. The unsaved
    values that the caller built before the call stay.
- `set_field_value` removes the values that it deletes from a loaded `custom_field_values`
  association. Before, the record also read the deleted values.
- `cama_permitted_field_options` keeps a group number that is a list or a hash, with its content
  removed, so the save fails. Before, the value went to group 0.
- **Behavior change:** a negative number and a String that is not digits are invalid. Before,
  `set_field_values` stored a negative number in group 0 and read a String with `to_i` (`'1abc'`
  was group 1), and `set_field_value` stored a negative number as given.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: a custom-field value with an invalid group number fails its
  save, on each write path.

## Impact

- `app/models/camaleon_cms/custom_fields_relationship.rb` (the validation),
  `app/models/concerns/camaleon_cms/custom_fields_read.rb` (`set_field_value` and `set_field_values`),
  `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb` (the permit),
  `config/locales/camaleon_cms/admin/*.yml` (the message, in each admin language).
- Specs: a new `spec/models/custom_field_value_group_number_spec.rb`, and examples in
  `spec/requests/security/field_options_non_hash_param_spec.rb`,
  `spec/models/custom_field_value_rejection_spec.rb` and
  `spec/controllers/concerns/camaleon_cms/admin/custom_fields_concern_spec.rb`.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers what changes.
- Ecosystem: `camaleon_export_import` passes the stored group number of an exported value to
  `set_field_value`, which is an integer or nil. The master branch of `camaleon-post-clone` copies
  the custom-field values of a post, so its clone of a post with a stored negative group number
  raises `ActiveRecord::RecordInvalid`. `docs/ai/ecosystem.md` records the survey.
