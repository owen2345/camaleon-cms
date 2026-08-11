## 1. Branch

- [x] 1.1 Create branch `security/reauth-impersonation-return` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit; a bare `GET /admin/logout` restores the admin for any holder of an abandoned impersonation (H6 residual, local access)

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/impersonation_return_reauth_spec.rb`: after impersonating, a bare `GET /admin/logout` must not hand the holder the admin's `auth_token` cookie
- [x] 2.2 Confirm it fails against the unfixed flow (one GET restores the admin)

## 3. Fix

- [x] 3.1 Route `back_to_parent` for GET+POST
- [x] 3.2 `SessionsController#logout` redirects to `back_to_parent` while impersonating (unless `?full=`), and `#back_to_parent` verifies the parent admin's password before `session_back_to_parent`
- [x] 3.3 Add `cama_impersonation_parent_user` to resolve the parent admin from the stash; note `session_back_to_parent` is post-re-auth only
- [x] 3.4 Add the `back_to_parent` confirmation view and i18n strings
- [x] 3.5 Confirm the reproduction now passes; add wrong-password, correct-password and log-out-completely cases

## 4. Cover the unchanged paths

- [x] 4.1 Update `impersonation_session_reset_spec` "returns the admin" case to the re-auth flow; keep the residue and logout-clears-stash cases green
- [x] 4.2 Run the session/redirect/helper request specs and the admin sign-in feature spec — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and session request specs — green
- [x] 5.2 `bin/rubocop` on touched files — no offenses (route files excluded from `Metrics/BlockLength`, as `spec/**/*` already is)
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: ending impersonation now requires the admin's password
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
