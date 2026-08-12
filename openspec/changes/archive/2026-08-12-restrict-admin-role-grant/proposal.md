## Why

Holding `:manage, :users` was a path to controlling admin accounts. `role_grantor?` only checked for that
capability, and `user_params` then assigned any submitted `role` — so a non-admin user manager could
create or edit an account with `role: 'admin'` (exactly what `User#admin?` tests), minting an admin and
escalating themselves, and could equally strip an existing admin's role. The capability-gating framework
(#1231) gates threats for non-admins, but changing who is an admin was left open (audit finding H10).

A follow-up `max` code review found the role permit was only half the boundary: the same `:manage, :users`
holder could still take over an admin by a non-role route — resetting the admin's password through
`#update`/`#updated_ajax` and signing in as them, or repointing the admin's email to hijack a
password-reset link. Left open, that made the goal ("`:manage, :users` is not a path to controlling admin
accounts") unmet, so this change also closes the credential vector. The review also flagged that a
malformed nested `user[role][x]` param `500`'d the request; that is hardened here too.

### Triage verdict: legit

Reproduced against master (`spec/requests/security/admin_role_grant_spec.rb`): a non-admin holding
`:manage, :users` created a new `role: 'admin'` account, promoted an existing user to admin, and stripped
an existing admin's role. All fail without the fix (confirmed by stashing it).

## What Changes

- `role_grantor?(other_user, new_role = nil)` now requires the acting user to be an admin whenever the
  role being granted is `admin` **or** the target user is already an admin; granting/changing any
  non-admin role is unchanged. The new argument is optional, so existing callers keep their behaviour.
- `user_params` passes the requested role to `role_grantor?`, so the permit drops a role change an
  unauthorised caller is not allowed to make — the account keeps its existing/default role. This is the
  server-side boundary.
- The user form no longer offers the `admin` option to someone who cannot grant it (and disables the role
  selector entirely when a non-admin edits an admin), while still listing the admin role when the edited
  user holds it so the form stays accurate.
- `UserDecorator#may_edit_credentials?(other_user)` returns `admin?` for an admin target and `true`
  otherwise. `user_params` drops `password`/`password_confirmation`/`email`/`username` for a non-admin
  editing an admin, and `updated_ajax` (the AJAX password endpoint) refuses with `403`. Self-edits and
  non-admin targets are unaffected. The form disables those inputs and hides the change-password action for
  anyone who cannot use them.
- `user_params` coerces a non-scalar `role` param to `nil` (only a `String` slug is honoured), so a
  malformed nested `user[role][x]` can no longer reach mass-assignment and raise.

## Out of scope

- Making `admin?` per-site (it is a global, cross-site role) — a data-model change, deliberately not
  attempted here (the other, by-design H10 residual).
