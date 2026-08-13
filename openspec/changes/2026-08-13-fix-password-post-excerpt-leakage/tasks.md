# Tasks

## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: only `post_the_content` is gated; `post_the_excerpt` is
  invoked by the decorator but implemented by no plugin

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/password_post_excerpt_leakage_spec.rb`: `/rss` must not carry a
  locked post's body; `the_excerpt` must return the neutral notice; a public post's excerpt must survive
- [x] 2.2 Confirm the examples fail against the unfixed plugin (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Extract `_visibility_password_locked?` and reuse it in `plugin_visibility_post_the_content`
- [x] 3.2 Implement `plugin_visibility_post_the_excerpt` (neutral `ct` notice) and register the hook in
  `config.json`
- [x] 3.3 Confirm the reproduction passes

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the new spec — green
- [ ] 4.3 `bin/brakeman --no-pager` — no new warnings (bundle-level pass before push)
- [ ] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean (bundle-level pass before push)

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: password-post excerpts/feeds no longer leak
- [ ] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
