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
field-options param into a 500. The range error is not new: release 2.2.0 already gives the group
number of the request to the row. The `NoMethodError` is present since 2.9.3, which added the
`to_i` call.

## What Changes

- `CamaleonCms::CustomFieldsRelationship` validates `group_number`: an integer from 0 to 2147483647.
  A text holds 1 to 16 ASCII digits. The validation reads the value before the integer cast. It runs on a new row, and on a stored row
  only when the number changes. A nil group number passes.
- `set_field_values` gives the group number to the row as the request sent it. An absent or empty
  group number is still group 0. The lower clamp and the `to_i` call go.
- An admin save that sends a refused group number redirects back with a flash error that names the
  field. The stored values stay, because the writer runs in a transaction. The create and the update
  of a post also roll back the attributes of the post. No other admin save rolls back what it stored
  before the values.
- The row refuses a group number text with a broken encoding, or in an encoding that is not
  ASCII-compatible (UTF-16). The integer type of Rails raises its own error for such a text, so the
  group number has its own integer type. The type reads the text as no number, and the validation
  refuses the text. A lookup with such a text finds no row. A save that skips the validation stops
  with the same refusal. An empty text in an encoding that is not ASCII-compatible gets the refusal
  too.
- The type of the group number has the 4-byte range on each database. Where the column holds a
  wider integer (SQLite, a `bigint` column), `where(group_number: n)` and `find_by(group_number: n)`
  find no row for a number n outside that range. A write that gives n as a value and skips the
  validation raises `ActiveModel::RangeError`. Before, those databases found and stored such a
  number.
- A copy (`dup`) of a row keeps the group number as the caller gave it to the original row. A copy
  is a new row, so the row checks that number. The copy of a stored row that holds a negative
  number, or a number above 2147483647 in a wider column, gets the refusal. Before, the copy stored
  that number.
- `set_field_value` and `set_field_values` ask for a savepoint inside a transaction of the caller. A
  refusal that the caller rescues there rolls back the delete of the stored values. The writers run
  one statement in that transaction first, so Rails opens the savepoint. Rails 8.1
  refuses that savepoint while the pool has an isolation level (for example under
  `ActiveRecord.with_transaction_isolation_level`). The writers then join a joinable transaction
  of the caller.
- `set_field_value` refuses the group number before its delete. A call with an empty list builds no
  row. Before, that call deleted the stored values of the group that the integer cast gave.
- `set_field_values` refuses the group number of an entry with no values. Before, it skipped that
  entry and did not read the number.
- `set_field_value` drops the rows that it deletes from a loaded `custom_field_values` association.
  Before, the record also read the deleted values.
- After an error, the two writers reset the `custom_field_values` association of the record. The
  record reads the stored values again, and its next save stores no row of the failed call. The
  unsaved rows that the caller built before the call stay in the association.
- `cama_permitted_field_options` gives a group number that is a list or a hash to the row, with no
  content. The row refuses it. Before, the permit dropped that number, and the save stored the value
  in group 0.
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
  `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb` (the permit),
  `config/locales/camaleon_cms/admin/*.yml` (the message, in each admin language).
- Specs: a new `spec/models/custom_field_value_group_number_spec.rb`, and examples in
  `spec/requests/security/field_options_non_hash_param_spec.rb`,
  `spec/models/custom_field_value_rejection_spec.rb` and
  `spec/controllers/concerns/camaleon_cms/admin/custom_fields_concern_spec.rb`.
- `docs/upgrading-to-2.9.5.md` tells plugin and theme developers about the refusal.
- Ecosystem: `camaleon_export_import` passes an exported row's group number to `set_field_value`, an
  integer or nil. Both pass. The master branch of `camaleon-post-clone` copies the value rows of a
  post, so its clone of a post with a refused stored number raises `ActiveRecord::RecordInvalid`.
  `docs/ai/ecosystem.md` records the survey.
