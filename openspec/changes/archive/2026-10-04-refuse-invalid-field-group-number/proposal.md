# Refuse a custom-field group number that the database cannot store

## Why

`CamaleonCms::CustomFieldsRead#set_field_values` takes each field's `group_number` from the request
with a lower bound only (`[values[:group_number].to_i, 0].max`), and `cama_permitted_field_options`
permits it as any scalar. The column is a 4-byte integer on PostgreSQL and MySQL.

- A number above 2147483647 raises `ActiveModel::RangeError` at `row.save!`. The request is a 500.
- A JSON body with `"group_number": true` or `false` raises `NoMethodError` on `to_i`. The request is
  a 500. A file sent as the group number does the same.
- `AdminController` rescues `ActiveRecord::RecordInvalid` for a custom-field value, not these two
  errors.

`custom-field-value-filtering` says that an authenticated caller MUST NOT turn a malformed
field-options param into a 500. The range error is not new: release 2.2.0 already gives the group
number of the request to the row. The `NoMethodError` is present since 2.9.3, which added the
`to_i` call.

## What Changes

- `CamaleonCms::CustomFieldsRelationship` validates the group number of a custom-field value. A
  group number is valid when it is nil, or an integer from 0 to 2147483647. A caller gives the
  integer as an Integer or as a text of 1 to 16 ASCII digits. The validation reads the group number
  as the caller gave it, before the integer cast of Rails. It checks a new value always, and a
  stored value only when its group number changes.
- `set_field_values` gives the group number to the value as the request sent it. An absent or empty
  group number is still group 0. The method no longer changes a negative number to 0, and it no
  longer calls `to_i`.
- An admin save that sends a group number that is not valid redirects back with a flash error that
  names the field. The record keeps its stored values, because `set_field_values` runs in a
  transaction. The create and the update of a post also roll back the new attributes of the post.
  Each other admin save keeps what it stored before the custom-field values.
- A group number text with a broken encoding, or in an encoding that is not ASCII-compatible
  (UTF-16), is not valid. The integer type of Rails raises its own encoding error for such a text,
  so the group number has its own integer type. That type gives nil for the text, and the
  validation then adds the usual error. A lookup with such a text finds no row. `update_attribute`
  and `save(validate: false)` stop with the same error. An empty text in an encoding that is not
  ASCII-compatible is not valid either.
- The type of the group number has the range of a 4-byte integer on each database. SQLite and a
  `bigint` column can hold a larger number. There, `where(group_number: n)` and
  `find_by(group_number: n)` find no row for a number n outside the range. A write of n that runs
  no validation raises `ActiveModel::RangeError`. Before, those databases found and stored such a
  number.
- A copy (`dup`) of a value keeps the group number as the caller gave it to the original value. A
  copy is a new value, so it is always checked. The copy of a stored value is not valid when that
  value holds a negative number, or a number above 2147483647. Before, the copy stored that number.
- `set_field_value` and `set_field_values` ask Rails for a savepoint inside a transaction of the
  caller. When the caller rescues their error there and commits, the delete of the failed call
  rolls back, and the stored values stay. The two methods run one statement in that transaction
  first, so that Rails opens the savepoint. Rails 8.1 permits no savepoint while the connection
  pool has an isolation level (for example under `ActiveRecord.with_transaction_isolation_level`).
  The two methods then run inside the transaction of the caller.
- `set_field_value` checks the group number before its delete. A call with an empty list of values
  builds no row. Before, that call deleted the stored values of the group that the integer cast
  gave.
- `set_field_values` checks the group number of an entry with no values. Before, it skipped that
  entry and did not read the number.
- `set_field_value` removes the rows that it deletes from a loaded `custom_field_values`
  association. Before, the record also read the deleted values.
- After a failed call, the two methods reset the `custom_field_values` association of the record.
  The record reads its stored values again, and its next save stores no row of the failed call. The
  unsaved rows that the caller built before the call stay in the association.
- `cama_permitted_field_options` keeps a group number that is a list or a hash, with its content
  removed, and the value is then not valid. Before, the permit dropped such a number, and the save
  stored the value in group 0.
- **Behavior change:** `set_field_values` gives an error for a negative group number and for a text
  that is not digits. Before, it stored a negative number in group 0 and read a text with `to_i`
  (`'abc'` was group 0, `'1abc'` was group 1). `set_field_value` gives an error for a negative
  group number. Before, it stored the number.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: a custom-field value is not valid when its group number is not an
  integer in the range of the column, on each write path.

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
- Ecosystem: `camaleon_export_import` passes the group number of an exported value to
  `set_field_value`. That number is an integer or nil, and both are valid. The master branch of
  `camaleon-post-clone` copies the custom-field values of a post. Its clone of a post that holds a stored group number that is not valid raises
  `ActiveRecord::RecordInvalid`.
  `docs/ai/ecosystem.md` records the survey.
