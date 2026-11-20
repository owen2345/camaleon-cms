# Tasks

## 1. Documents

- [x] 1.1 Add a comment at `FIELD_ENTRY_FILTER` in
  `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb`. The comment marks the drop
  of a list that holds a hash as intended. Verify: `bin/rubocop -A` reports no offense
- [x] 1.2 Add the reason to the requirement of the two `values` shapes, in the delta spec of this
  change. Divide the first sentence of the requirement in two. Verify: the four scenarios of the requirement stay as
  they are
- [x] 1.3 Add a bullet to `docs/ai/ecosystem.md` that names the `my_slider` field of three themes.
  Verify: the Markdown gate prints no line

## 2. Verification and shipping

- [x] 2.1 Run `openspec validate --all --strict`. Verify: the change is valid
- [ ] 2.2 Add the `CHANGELOG.md` entry with the link of the PR, and archive this change on the
  branch. Verify: `openspec validate --archived` passes
