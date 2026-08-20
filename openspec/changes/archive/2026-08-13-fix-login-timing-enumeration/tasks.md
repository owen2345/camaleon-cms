## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: `@user&.authenticate` skips bcrypt for a missing username

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/login_timing_enumeration_spec.rb`: a missing-username login must run a bcrypt `is_password?` comparison; a real user still logs in
- [x] 2.2 Confirm the timing example fails against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Add `cama_password_matches?` and a precomputed dummy digest; call it from `login_post`
- [x] 3.2 Confirm the reproduction passes and real logins still work

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the touched spec and the login/session security specs — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: login equalizes timing for unknown usernames
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
