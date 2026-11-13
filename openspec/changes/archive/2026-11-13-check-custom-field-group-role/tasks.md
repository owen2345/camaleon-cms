# Tasks

## 1. The role check

- [x] 1.1 Add `spec/requests/security/custom_field_group_role_check_spec.rb`. A Contributor must get
  a redirect for `reorder`, and the order must stay. The same user must get a redirect for the list,
  the two forms, the page of a group and the settings of a field kind. A role with the
  `custom_fields` permission must store a new order and get the form. Make sure that the examples of
  the Contributor fail before the fix.
- [x] 1.2 Check the role for each action except `list` in `custom_fields_controller.rb` (D1).
- [x] 1.3 Give the change in `docs/upgrading-to-2.9.5.md` and in `docs/security/permissions.md`.

## 2. Verification and shipping

- [x] 2.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 2.2 Add the CHANGELOG entry, archive this change on the branch
