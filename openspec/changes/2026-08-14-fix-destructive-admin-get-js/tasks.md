# Tasks

## 1. Branch and triage

- [x] 1.1 Branch `security/m6-destructive-get-js` off the post-#1264 master
- [x] 1.2 Confirm the triage verdict — ✅ legit: `item_delete` routed over `get`,
  `widgets`/`widget_delete` admit GET, `crop` admits every verb (`via: :all`)
- [x] 1.3 Ecosystem scan (sibling clones): no consumer of any of the three paths, no plugin
  defines the dead `AppearancesController`; record dispositions in the proposal

## 2. Reproduce first

- [x] 2.1 Extend `spec/requests/security/admin_destructive_get_verbs_spec.rb`: GETs must perform
  no state change (menu item survives, avatar meta unchanged, widgets route table admits no
  GET/HEAD); the converted verbs must perform the actions
- [x] 2.2 Confirm the examples fail against the unfixed routes (spec-first red run)

## 3. Fix — one commit per route

- [x] 3.1 Commit 1: nav_menus `item_delete` → DELETE; `nav_menu.js` sends the token-bearing
  `$.ajax type: 'DELETE'`; `delete_menu_item` leaves `allowed_get_actions`
- [ ] 3.2 Commit 2: appearances `widgets` → DELETE-only, `widget_delete` → PATCH-only (no callers
  exist to fix); `widget_delete` leaves `allowed_get_actions`
- [ ] 3.3 Commit 3: media `crop` → POST-only; `crop_spec.rb` converts its requests to POST; `crop`
  leaves `allowed_get_actions` (allowlist ends at the logout/back_to_parent pair);
  `docs/ai/ecosystem.md`'s M6 entry records the follow-up-2 outcome

## 4. Verification

- [ ] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [ ] 4.2 `bin/rspec` on the reproduction spec, the routing audit, `crop_spec.rb`, and the menus
  `:js` feature spec — green
- [ ] 4.3 `bin/brakeman --no-pager` — no new warnings
- [ ] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [ ] 5.1 Add a `## Unreleased` **Security fix** entry once the PR number exists
- [ ] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
