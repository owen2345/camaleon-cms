# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/admin/custom_field_numeric_slug_spec.rb`. A post save and a draft save
  store a post type field beside a field `2020` of the post itself. A save stores a registered field
  beside a numeric key that names no field. A save stores a registered field `2020` and the field
  beside it. A save stores the values of an entry that also holds a numeric key. Verify: each example
  fails on the current permit, except the registered `2020` example (design D4)
- [x] 1.2 Add examples to `spec/controllers/concerns/camaleon_cms/admin/custom_fields_concern_spec.rb`.
  The permit keeps the entry of an allowed slug beside a numeric slug outside its scope. The permit
  keeps the `id`, group number and values of an entry that holds a numeric key. Verify: both fail on
  the current permit

## 2. The permit

- [x] 2.1 Permit each field entry on its own in `cama_permitted_field_options` (design D1), and
  remove the post-permit cleanup. Change the comments above the permit to say what the code now
  does. Verify: the specs of 1.1 and 1.2 pass
- [x] 2.2 Verify that the existing field-options specs stay green: the specs that
  `grep -rlF --exclude-dir=dummy -e cama_permitted_field_options -e field_options spec/` lists

## 3. Documentation

- [x] 3.1 Add an at-a-glance row and a section to `docs/upgrading-to-2.9.5.md`. They name the records
  to review and the unpermitted-parameter change (design D3). Verify: the anchor of the row resolves
  to the heading of the section, and the Markdown gate prints no line

## 4. Verification and shipping

- [x] 4.1 Run `bin/rubocop -A`, `bin/rspec` on the new specs and the adjacent specs,
  `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`. Verify: each check
  passes
- [x] 4.2 Run `openspec validate --all --strict`. Verify: the change is valid
- [ ] 4.3 Open the PR, add the `CHANGELOG.md` entry with the link of the PR, and archive this change
  on the branch. Verify: `openspec validate --archived` passes
