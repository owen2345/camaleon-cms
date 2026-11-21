# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/admin/refused_draft_save_spec.rb`. It refuses a draft create of a new
  post and the first draft create under a post. It also refuses a draft create on a buffer and a
  draft update. Each case runs with a value that the scan refuses and with `values` that the permit
  does not keep. Verify: each of these examples fails on the current controller

## 2. The draft save

- [x] 2.1 Add `save_draft_with_fields` to `DraftsController` and call it from `create` and `update`
  (design D1 to D3). Verify: the spec of 1.1 passes
- [x] 2.2 Change the three specs that expected the draft row or the new title to stay:
  `spec/requests/admin/custom_field_unusable_values_spec.rb`,
  `spec/requests/admin/appearances/xhr_save_refusal_spec.rb` and
  `spec/features/admin/post_draft_refused_value_spec.rb`. Verify: the feature spec still finds the
  refusal in the alert of the post editor

## 3. Documentation

- [x] 3.1 Change the comment of `rescue_from ActiveRecord::RecordInvalid` in `AdminController`, and
  the two sections of `docs/upgrading-to-2.9.5.md` that name the draft save. Verify: the Markdown
  gate prints no line

## 4. Verification and shipping

- [x] 4.1 Run `bin/rubocop -A`, `bin/rspec` on the new spec and the adjacent specs,
  `bin/brakeman --no-pager` and `(cd spec/dummy && bin/rails zeitwerk:check)`. Verify: each check
  passes
- [x] 4.2 Run `openspec validate --all --strict`. Verify: the change is valid
- [ ] 4.3 Open the PR, add the `CHANGELOG.md` entry with the link of the PR, and archive this change
  on the branch. Verify: `openspec validate --archived` passes
