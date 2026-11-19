# Tasks

## 1. Specs

- [x] 1.1 Send a list param, a list group and a scalar field entry in
  `spec/requests/security/custom_fields_form_malformed_field_options_spec.rb`, on the post form and
  on the category form. Verify: each example checks that the form rendered the custom-fields
  partial, and the spec passes

## 2. Verification and shipping

- [x] 2.1 Run `openspec validate --all --strict`. Verify: the change is valid
- [x] 2.2 Add the `CHANGELOG.md` entry with the link of the PR, and archive this change on the
  branch. Verify: `openspec validate --archived` passes
