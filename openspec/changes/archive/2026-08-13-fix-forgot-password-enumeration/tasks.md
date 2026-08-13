## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: distinct known/unknown response + one email per request

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/forgot_password_enumeration_spec.rb`: known/unknown answer identically; a second request within the window sends no second email
- [x] 2.2 Confirm the unknown-email and cooldown examples fail against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Respond with one neutral notice + redirect regardless of account existence (new `password_reset_requested` locale key)
- [x] 3.2 Gate the send on a per-account cooldown (`cama_password_reset_email_allowed?`, `PASSWORD_RESET_EMAIL_COOLDOWN`)
- [x] 3.3 Confirm the reproductions pass

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the touched spec and the password-reset / session security specs — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: forgot-password no longer enumerates accounts or re-sends unthrottled
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
