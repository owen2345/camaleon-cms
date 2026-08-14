# Tasks

## 1. Branch

- [x] 1.1 Branch `security/m6-destructive-get-links` off the freshly pulled master (#1263 merged)
- [x] 1.2 Confirm the triage verdict — ✅ legit: all seven endpoints routed over `get`, callers are
  plain links / `$.get`

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/admin_destructive_get_verbs_spec.rb`: GETs must perform no
  state change; the converted verbs must perform the actions; logout must confirm on GET and act
  only on POST
- [x] 2.2 Confirm the examples fail against the old routes (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Convert the routes (trash/restore/toggle_status/toggle → PATCH; upgrade/impersonate/
  test_email → POST; logout → GET confirmation + POST action)
- [x] 3.2 Update every first-party caller: `method:` links in admin views and the comment helper,
  `$.post` in the test-email dialog, `button_to` for all four logout call sites
- [x] 3.3 Preserve the impersonation redirect and the de-authenticated cleanup in `#logout`
- [x] 3.4 Update the pre-existing suites that drove the endpoints over GET to the new verbs
- [x] 3.5 Confirm the reproduction and all affected suites pass

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the reproduction spec and the eleven affected suites — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: destructive admin actions no longer ride GET
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
