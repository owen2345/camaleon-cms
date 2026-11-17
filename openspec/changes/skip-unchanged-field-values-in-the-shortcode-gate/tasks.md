# Tasks

## 1. The gate

- [x] 1.1 Add `spec/requests/security/shortcode_gate_unchanged_field_value_spec.rb`. Make sure that
  the title change fails without the fix.
- [x] 1.2 Add `previously_stored!` and set it in `set_field_values` (D1).
- [x] 1.3 Skip a marked row in both gates (D1, D2).

## 2. Verification and shipping

- [x] 2.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 2.2 Add the CHANGELOG entry, archive this change on the branch
