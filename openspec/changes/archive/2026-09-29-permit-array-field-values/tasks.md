# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/admin/custom_field_list_values_spec.rb`: a site settings save and a post
  save submitting a checkboxes field's `values` as a list store the values in order; a stored value
  survives a save submitting it again; a save carrying a text box keyed by index beside the list
  stores both; a list of hashes stores nothing. Confirm the list examples fail against the unfixed
  permit
- [x] 1.2 Add examples to `spec/controllers/concerns/camaleon_cms/admin/custom_fields_concern_spec.rb`:
  the permit keeps a list of scalars and drops a list of hashes; confirm the first fails unfixed

## 2. The permit

- [x] 2.1 Permit `{ values: [] }` beside `{ values: {} }` in `cama_permitted_field_options` (D1); the
  1.1 and 1.2 specs pass and the existing field-option specs stay green

## 3. Documentation

- [x] 3.1 Tell upgraders in `docs/upgrading-to-2.9.5.md` that checkboxes fields are stored again and
  which records to review (an at-a-glance row and its section), and plugin developers that the permit
  keeps a list; the row's anchor resolves to the section's heading

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A` on the touched files, `bin/rspec` on the new specs and the adjacent ones
  (`grep -rln cama_permitted_field_options spec/`, the custom-field request and model specs),
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 4.2 Open the PR, add the CHANGELOG entry, archive this change on the branch

## 5. Review follow-ups

- [x] 5.1 Keep only the entries of an allowed slug in the permit (D3);
  `spec/requests/security/field_options_non_hash_param_spec.rb` updates a category that holds a value
  with a group under a numeric key and expects the value kept
- [x] 5.2 Share one filter between all groups (D4); the helper spec sends three groups with both shapes
- [x] 5.3 Add `spec/features/admin/custom_field_checkboxes_spec.rb`: the real site settings form stores
  the checked options and removes the unchecked ones
- [x] 5.4 Add a list-shaped refusal example to `spec/requests/security/custom_field_value_rejection_spec.rb`
- [x] 5.5 Record the numeric-key scenario in `custom-field-value-filtering` and the survey of the
  helper's callers in `docs/ai/ecosystem.md`
