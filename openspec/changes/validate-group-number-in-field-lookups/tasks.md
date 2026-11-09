# Tasks

## 1. Reproduce first

- [x] 1.1 Add reader examples to `spec/models/custom_field_value_group_number_spec.rb`: an invalid
  group number, a negative Integer and a list. Add examples with a loaded association and a Symbol
  key or a String of digits
- [x] 1.2 Add `update_field_value` examples to the same spec: an invalid group number, a negative
  Integer, and a loaded association
- [x] 1.3 Add an example with a slug in UTF-16 and an invalid group number
- [x] 1.4 Add an example that reads a loaded row through its `value` reader

## 2. The fix

- [x] 2.1 Read the values of `get_field_values` through one private lookup that tests the group
  number (D1 to D5)
- [x] 2.2 Validate the group number in `update_field_value` before its lookup, and look the value
  up in the database (D6 to D8)
- [x] 2.3 Put the slug in UTF-8 into the message of the group number error (D9)
- [x] 2.4 Read the value of a loaded row with its `value` reader (D10)
- [x] 2.5 Delete the values of `set_field_value` through the lookup (D11)

## 3. Documentation

- [x] 3.1 Give the reads of each kind of group number in `docs/upgrading-to-2.9.5.md`, and record
  the survey of the callers in `docs/ai/ecosystem.md`
- [x] 3.2 Give the error of `update_field_value` in the same guide, and record its callers in the
  ecosystem inventory

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 4.2 Open the PR, add the CHANGELOG entries, archive this change on the branch
