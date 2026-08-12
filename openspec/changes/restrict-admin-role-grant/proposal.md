## Why

Holding `:manage, :users` was a path to controlling admin accounts. `role_grantor?` only checked for that
capability, and `user_params` then assigned any submitted `role` — so a non-admin user manager could
create or edit an account with `role: 'admin'` (exactly what `User#admin?` tests), minting an admin and
escalating themselves, and could equally strip an existing admin's role. The capability-gating framework
(#1231) gates threats for non-admins, but changing who is an admin was left open (audit finding H10).

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

## Out of scope

- Making `admin?` per-site (it is a global, cross-site role) — a data-model change, deliberately not
  attempted here (the other, by-design H10 residual).
