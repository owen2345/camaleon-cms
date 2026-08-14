# Tasks

## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: `editor` values render `raw` and URI-type values render
  into href/src with no save gate

## 2. Reproduce first

- [x] 2.1 Add `spec/models/custom_field_value_rejection_spec.rb` and
  `spec/requests/security/custom_field_value_rejection_spec.rb`: a script editor value and a
  `javascript:` URL from an untrusted author must be refused, benign values stored unchanged
- [x] 2.2 Confirm the rejection examples fail against the ungated code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Add `CamaleonCms::UnsafeMarkup` (shared scan-and-reject detector, in parity with the
  cama_contact_form gate)
- [x] 3.2 Validate `CustomFieldsRelationship` by rendered position (editor → markup gate with the
  post-content allowlist; url/media → scheme gate), trust mirroring the post-content model, fail
  closed without context, `unfiltered_value!` pipeline opt-out
- [x] 3.3 Rescue the refusal in `AdminController` into a flash error naming the field
- [x] 3.4 Confirm the reproduction passes

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on both rejection specs — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings (bundle-level pass before push)
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean (bundle-level pass before push)

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: dangerous custom-field values are rejected on save
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
