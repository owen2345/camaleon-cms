## 1. Branch

- [x] 1.1 Create branch `security/restrict-admin-role-grant` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit; `role_grantor?` only checks `:manage, :users`, so a non-admin user manager can set `role: 'admin'` (or strip an admin) via `user_params` on create/update

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/admin_role_grant_spec.rb`: a non-admin `:manage, :users` holder must not create/promote an account to `admin` nor strip an existing admin; must still change non-admin roles; an admin must still grant and change the admin role
- [x] 2.2 Confirm the escalation and admin-strip examples fail against the unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 `role_grantor?(other_user, new_role = nil)` requires `admin?` when `new_role` is `admin` or the target is already an admin
- [x] 3.2 `user_params` passes the requested role so the permit drops an admin grant/strip from a non-admin
- [x] 3.3 The user form omits the `admin` option for anyone who cannot grant it and disables the selector when a non-admin edits an admin (kept when the edited user already holds it)
- [x] 3.4 Confirm the reproductions now pass

## 4. Cover the unchanged paths

- [x] 4.1 Run the users mass-assignment spec (stubs `role_grantor?`) and the member-route resolution spec — green
- [x] 4.2 Run the admin users feature spec (admin still grants any role through the form) — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and related user specs — green
- [x] 5.2 `bin/rubocop` on touched files — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: granting the admin role now requires being an admin
- [x] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
