## 1. Branch

- [x] 1.1 Work on the shared `security/tier3-hardening` branch (bundled Tier-3 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: plain jar, no HttpOnly/Secure, logout does not rotate the token
- [x] 1.3 Confirm the scope decision with the maintainer — rotate on logout (logout-everywhere); encryption deliberately out of scope

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/auth_cookie_hardening_spec.rb`: login cookie is HttpOnly, Secure over SSL (not over HTTP), and the token rotates on logout
- [x] 2.2 Confirm the HttpOnly / Secure / rotation examples fail against unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Add `cama_auth_cookie_options` (HttpOnly + Secure-over-SSL) and use it at both auth-cookie write sites
- [x] 3.2 Add `User#cama_reset_auth_token!` and rotate on logout in `cama_logout_user`
- [x] 3.3 Confirm the reproduction passes and the login/logout/impersonation/forced-change suites stay green

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec` on the auth-cookie spec and the full auth/session/impersonation suites — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: auth cookie is HttpOnly/Secure and the token rotates on logout
- [ ] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
