# Tasks

## 1. The group numbers

- [x] 1.1 Add the feature spec `spec/features/admin/custom_field_repeat_group_numbers_spec.rb` and
  the helper examples of `cama_form_field_group_numbers`. Make sure that they fail without the fix.
- [x] 1.2 Add `cama_form_field_group_numbers` (D2).
- [x] 1.3 Pass the numbers from the partial to `build_custom_field_group`, and keep them in the
  editor (D1, D3, D4).

## 2. Verification and shipping

- [x] 2.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 2.2 Add the CHANGELOG entry, archive this change on the branch
