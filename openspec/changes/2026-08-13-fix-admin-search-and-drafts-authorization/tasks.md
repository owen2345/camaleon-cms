## 1. Branch

- [x] 1.1 Work on the shared `security/tier2-hardening` branch (bundled Tier-2 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: `AdminController` gates only on login, so a client reaches `#search` (no filter) and `DraftsController#index` (no `authorize!`)

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/admin_search_authorization_spec.rb`: a client's content search must not list an unpublished title; the drafts index must not return 200 JSON to a client; an admin retains access
- [x] 2.2 Confirm the client examples fail against unfixed code (stash the fixes, run, restore)

## 3. Fix

- [x] 3.1 `search`: scope each kind to the caller's `can? :posts` post types; scope content to accessible types and to own posts where `edit_other` is absent
- [x] 3.2 `DraftsController#index`: add `authorize! :posts, @post_type`
- [x] 3.3 Confirm the reproductions pass and an admin still searches everything / reaches the drafts index

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec spec/requests/security/admin_search_authorization_spec.rb` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: admin search and the drafts index now enforce authorization
- [ ] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
