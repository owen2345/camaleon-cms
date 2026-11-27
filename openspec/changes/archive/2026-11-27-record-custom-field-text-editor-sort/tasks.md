# Tasks

## 1. Record the rules

- [x] 1.1 Add the `custom-field-text-editor-sort` spec. Each scenario names a case of
  `spec/features/admin/custom_field_editor_sort_spec.rb` or
  `spec/features/admin/custom_field_editor_id_spec.rb`. Verify: each scenario has an example in
  these specs
- [x] 1.2 Run `openspec validate --all --strict`. Verify: no error and no warning

## 2. Archive

- [x] 2.1 Archive the change on the branch, with the sync of the delta spec. Verify:
  `openspec validate --archived` passes
