## 1. Branch

- [x] 1.1 Create branch `security/sort-by-field-order-injection` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit (scoped): interpolated ORDER direction; Rails' guard blocks arbitrary SQL but a hostile direction still 500s and a comma continuation still injects an extra ORDER BY term

## 2. Reproduce first

- [x] 2.1 Add `spec/initializers/active_record_extension_spec.rb`: legit asc/desc/default sort, a stacked/comment direction, and a comma-continuation direction
- [x] 2.2 Confirm the three hostile-direction examples fail against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Whitelist the direction to `ASC`/`DESC` (case-insensitive `DESC`, else ascending) — no interpolation
- [x] 3.2 Order by a quoted Arel column (`CustomFieldsRelationship.arel_table[:value]`) instead of an interpolated string
- [x] 3.3 Confirm the reproductions now pass and legitimate sorting is unchanged

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the touched spec and `spec/requests/security/` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: `sort_by_field` whitelists the ORDER direction and quotes the column
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
