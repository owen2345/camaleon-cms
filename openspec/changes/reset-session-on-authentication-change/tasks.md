## 1. Branch

- [x] 1.1 Create branch `security/reset-session-on-auth-change` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict before writing the fix — ✅ legit; impersonation residue in `session[:parent_auth_token]` survives a fresh sign-in and is restored on `/admin/logout`, escalating a low-priv user to admin (detail in `proposal.md`)

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/impersonation_session_reset_spec.rb`: drive real impersonation to seed the residue, sign in as an unrelated low-priv user, hit `/admin/logout`, and assert the resulting `auth_token` cookie is not the admin's
- [x] 2.2 Confirm that example fails against the unfixed helper (stash the fix, run, restore) — the escalated cookie is the admin's token without the fix
- [x] 2.3 Add a second example asserting normal impersonation still returns the admin to their own session

## 3. Fix

- [x] 3.1 `login_user` calls `reset_session` on a genuine sign-in, gated by a new `rotate_session:` keyword (default `true`)
- [x] 3.2 `session_switch_user` resets the session, then stashes the admin's token and calls `login_user(..., rotate_session: false)` so impersonation is preserved
- [x] 3.3 `cama_logout_user` calls `reset_session` on logout
- [x] 3.4 Confirm both spec examples now pass

## 4. Cover the unchanged paths

- [x] 4.1 Run the session-return open-redirect request spec — `return_to` (cookie and param) still redirects correctly through the reset
- [x] 4.2 Run the session helper spec and the admin sign-in feature spec (real login/logout/forgot/register UI) — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the new spec plus the session/redirect/helper specs and the sign-in feature spec — green
- [x] 5.2 `bin/rubocop` on touched files only — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: impersonation residue could escalate a later sign-in to admin; the session is now reset on sign-in and logout. Note the downstream hook caveat.
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
