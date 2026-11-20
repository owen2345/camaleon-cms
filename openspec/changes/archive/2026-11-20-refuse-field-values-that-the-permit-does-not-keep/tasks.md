# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/admin/custom_field_unusable_values_spec.rb`. A site save submits valid
  values for one field and a list of hashes, a nested list or a scalar for another field. Verify: the
  stored values of the second field are gone on the current permit, and the save reports success
- [x] 1.2 Add an example for a checkboxes field with no option checked. Verify: it passes on the
  current permit

## 2. The refusal

- [x] 2.1 Add `UnusableFieldValues` and the check to `cama_permitted_field_options` (design D2, D3).
  Verify: the examples of 1.1 keep the stored values
- [x] 2.2 Add the `rescue_from` to `CamaleonCms::AdminController` and the message `values_unusable`
  to `en.yml`. Verify: the request spec reads the flash message, the 422 of an XHR and the post that
  keeps its title
- [x] 2.3 Change the examples of `custom_fields_concern_spec.rb` and
  `custom_field_list_values_spec.rb` that pinned the silent drop. Verify: they read the error

- [x] 2.4 Refuse the entry of an allowed slug that is a scalar or a list (design D5). Add the examples
  to the request spec and to `custom_fields_concern_spec.rb`, and change the example of a list entry
  in `field_options_non_hash_param_spec.rb`. Verify: the new examples fail before the check

## 3. Documentation

- [x] 3.1 Add an at-a-glance row and a section to `docs/upgrading-to-2.9.5.md`. Verify: the anchor of
  the row resolves to the heading of the section, and the Markdown gate prints no line
- [x] 3.2 Record the consumers of the permit in `docs/ai/ecosystem.md`

## 4. Verification and shipping

- [x] 4.1 Run `bin/rubocop -A`, `bin/rspec` on the new specs and the adjacent specs,
  `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`. Verify: each check
  passes
- [x] 4.2 Run `openspec validate --all --strict`. Verify: the change is valid
- [x] 4.3 Open the PR, add the `CHANGELOG.md` entry with the link of the PR, and archive this change
  on the branch. Verify: `openspec validate --archived` passes
