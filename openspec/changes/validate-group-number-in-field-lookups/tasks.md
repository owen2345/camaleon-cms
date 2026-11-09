# Tasks

## 1. Reproduce first

- [x] 1.1 Add reader examples to `spec/models/custom_field_value_group_number_spec.rb`: an invalid
  group number, a negative Integer and a list. Add examples with a loaded association and a Symbol
  key or a String of digits

## 2. The fix

- [x] 2.1 Read the values of `get_field_values` through one private lookup that tests the group
  number (D1 to D5)

## 3. Documentation

- [x] 3.1 Give the reads of each kind of group number in `docs/upgrading-to-2.9.5.md`, and record
  the survey of the callers in `docs/ai/ecosystem.md`

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 4.2 Open the PR, add the CHANGELOG entries, archive this change on the branch
