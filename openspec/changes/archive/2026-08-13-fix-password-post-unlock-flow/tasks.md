# Tasks

## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: method-less form (GET), `type='text'`, `==` comparison

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/password_post_unlock_flow_spec.rb`: GET parameter must not
  unlock; prompt must be a POST/password-type form; POST unlock must gate on the password and persist
  in the session; non-password posts must 404
- [x] 2.2 Confirm the examples fail against the unfixed plugin (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Add `config/routes_front.txt` + `Plugins::VisibilityPost::FrontController#unlock`
  (site-scoped lookup, `secure_compare`, session marker, flash flag, redirect back)
- [x] 3.2 Rewrite `_password_form` (POST action, CSRF token, password input, error display) and swap
  the lock predicate's unlock source to the session marker
- [x] 3.3 Rewrite the feature-spec unlock example to the browser flow (fill form, submit)
- [x] 3.4 Confirm the reproduction and the feature flow pass

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on both password-post request specs and the visibility feature specs — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings (bundle-level pass before push)
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean (bundle-level pass before push)

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: password-post unlock moves to POST + session
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR
  (`docs/ai/workflows.md` Phase 4)
