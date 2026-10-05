# Tasks

## 1. Reproduce first

- [x] 1.1 Add examples to `spec/requests/security/field_options_non_hash_param_spec.rb`: a category
  update with a group number above the range, a negative number, a text, a JSON boolean and a file
  redirects with the error and keeps the stored value. Confirm that they fail on the unfixed code
- [x] 1.2 Add `spec/models/custom_field_value_group_number_spec.rb`: `set_field_value` refuses such
  numbers and keeps the stored value, a nil number and the largest number pass, a stored row with a
  negative number stays writable

## 2. The remedy

- [x] 2.1 Validate the group number in `CamaleonCms::CustomFieldsRelationship` (D1 to D4) and add
  the message to each admin locale file
- [x] 2.2 Give the group number to the value as the request sent it, in `set_field_values` (D5, D6)
- [x] 2.3 Refuse a group number text with a broken encoding, or in an encoding that is not
  ASCII-compatible, in the value model and before the lookup of `set_field_value`, with examples in
  the model spec (D7)
- [x] 2.4 Stop a save that skips the validation for such a text with a `before_save` callback, with
  examples in the model spec (D7)
- [x] 2.5 Give the cast a Symbol in `write_attribute`, so `[]=` gets the same error, with examples in the
  model spec (D7)
- [x] 2.6 Keep the given group number in a copy of a value (`initialize_dup`), with examples in the
  model spec (D8)
- [x] 2.7 Move the guards of 2.3 and 2.5 to an integer type for the group number, which also covers
  a lookup, with examples in the model spec (D7)
- [x] 2.8 Ask for a savepoint in `set_field_value` and `set_field_values`, so an error that the caller
  rescues inside its own transaction rolls the delete back, with examples in the model specs (D9)
- [x] 2.9 Reset the association of the record when one of the two methods fails, so the record reads
  the stored values and its next save stores no row of the call, with examples in the model specs
  (D10)
- [x] 2.10 Check the group number in `set_field_value` before the delete, so a call with an empty
  list gets the error, with examples in the model spec (D11)
- [x] 2.11 Put the unsaved rows that the caller built before the call back after the reset, with
  examples in the model spec (D10)
- [x] 2.12 Keep a group number that is a list or a hash in `cama_permitted_field_options`, so an
  admin save gets the error, with examples in the request spec and in the spec of the permit helper
  (D12)
- [x] 2.13 Reset the association after each failed call: an exception of any class, a `throw` or a
  rollback of the call, also in the commit phase, with examples in the model spec (D10)
- [x] 2.14 Run inside the transaction of the caller while the pool has an isolation level (Rails 8.1),
  with examples in the model spec (D9)
- [x] 2.15 Refuse a group number text of more than 16 bytes, with examples in the model and request
  specs (D2)
- [x] 2.16 Check the group number of an entry with no values in `set_field_values`, with model and
  request examples (D14)
- [x] 2.17 Remove the rows that `set_field_value` deletes from a loaded association, with examples in
  the model spec (D15)
- [x] 2.18 Run one statement in the transaction of the caller before the two methods ask for the
  savepoint, with model examples (D9)

## 3. Documentation

- [x] 3.1 Add the note for plugin and theme developers to `docs/upgrading-to-2.9.5.md`
- [x] 3.2 Record the survey of the consumers in `docs/ai/ecosystem.md`
- [x] 3.3 Record the three writes that skip the validation and the callbacks in the upgrade note and
  in the requirement (D7)
- [x] 3.4 Record the 4-byte range of the type on a column for a larger integer in the upgrade note,
  in the requirement and in a comment on the type (D3)
- [x] 3.5 Record that the copy of a stored value with a number outside the range is not valid: in
  the upgrade note, in the requirement, in the ecosystem survey and in a comment of the model (D8)
- [x] 3.6 Record a callback of a value that raises `ActiveRecord::Rollback` in the upgrade note, in
  the requirement and in a comment of `_cama_write_field_values`, with an example in the model spec
  (D10)
- [x] 3.7 Record the connection pool of the transaction of the two methods in the upgrade note, in
  the requirement and in a comment of `_cama_write_field_values` (D13)
- [x] 3.8 Record the cost of the savepoint in the upgrade note (D9)

## 4. Verification and release steps

- [x] 4.1 `bin/rubocop -A` on the touched files, `bin/rspec` on the new specs and the adjacent ones,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
