# Tasks

## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: raw-interpolated stored JSON, no save gate, value
  column never rendered

## 2. Reproduce first

- [x] 2.1 Add field_attrs gate examples to `custom_field_value_rejection_spec.rb` (literal and
  unicode-escaped script bytes refused; benign and admin pairs verbatim) and rewrite
  `render_custom_field_field_attrs_spec.rb` (verbatim render, value-not-label bugfix)
- [x] 2.2 Confirm the gate and bugfix examples fail against the ungated code (stash, run, restore)

## 3. Fix

- [x] 3.1 Add `JSON_MARKUP_FIELD_KEYS` to `CustomFieldsRelationship` and scan the decoded JSON
  members with the shared markup gate
- [x] 3.2 Render the stored pair verbatim in the partial and fix the value/label bug
- [x] 3.3 Confirm the reproduction passes

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on both specs — green
- [ ] 4.3 `bin/brakeman --no-pager` — no new warnings (bundle-level pass before push)
- [ ] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean (bundle-level pass before push)

## 5. Changelog and archive

- [x] 5.1 Rework the `## Unreleased` **Security fix** entry: field_attrs values gated on save,
  rendered verbatim
- [ ] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
