## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: only presence + 72-byte max were validated

## 2. Reproduce first

- [x] 2.1 Add `spec/models/password_strength_policy_spec.rb`: a 7-char password is invalid, 8+ is valid, a no-password update still saves
- [x] 2.2 Confirm the short-password example fails against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Add `validates :password, length: { minimum: 8 }, allow_blank: true` to the default User model
- [x] 3.2 Update the one pre-existing spec that used a sub-8 throwaway password
- [x] 3.3 Confirm the reproduction passes and the model/session/security suites stay green

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec spec/models/ spec/requests/security/` — green (no password-length regressions)
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: passwords must be at least 8 characters
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
