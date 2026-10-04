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
- [x] 2.2 Give the group number to the row as sent in `set_field_values` (D5, D6)
- [x] 2.3 Refuse a group number text with a broken encoding in `set_field_value` and
  `set_field_values`, with examples in the model spec (D7)

## 3. Documentation

- [x] 3.1 Add the note for plugin and theme developers to `docs/upgrading-to-2.9.5.md`
- [x] 3.2 Record the survey of the consumers in `docs/ai/ecosystem.md`

## 4. Verification and release steps

- [x] 4.1 `bin/rubocop -A` on the touched files, `bin/rspec` on the new specs and the adjacent ones,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
