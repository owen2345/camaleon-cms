# Design

## D1. Enforce at the role permit — the actual boundary

Every role assignment flows through one place: `UsersController#user_params`, which sets `p[:role]` only
when `role_grantor?` allows it. That is the security boundary, so the check belongs there. Making it
role-value-aware — pass the submitted role to `role_grantor?` — closes the escalation regardless of what
the UI offers. An unpermitted `admin` grant is simply dropped (the account keeps its existing or default
role), matching how the rest of the controller's mass-assignment protection fails safe.

## D2. `admin` is the exact role that confers superadmin — guard both directions

`User#admin?` is `role == 'admin'`, and `Ability` grants `can :manage, :all` to `admin?` users. So the one
role a non-admin must not be able to hand out is the literal `admin` slug — a custom role can carry
specific manage capabilities but never `:manage, :all`. But admin-ness must be symmetric: a `:manage,
:users` holder must not be able to *strip* an admin either (removing an admin is escalation-adjacent
tampering with the privileged set). `role_grantor?` therefore requires `admin?` when **either** the new
role is `admin` **or** the target already has the `admin` role, and leaves every all-non-admin role change
grantable by a `:manage, :users` holder. The `new_role` argument is optional so the existing no-argument
callers (and any downstream plugin/theme use of this public decorator method) keep working — a plain
`role_grantor?(user)` still answers "may set this user's role at all", which is what the form's
enable/disable check wants, and it now returns false when a non-admin views an admin.

## D3. The form mirrors the enforcement

Left unchanged, the role `<select>` would still list `admin` to a non-admin, who would pick it and see it
silently dropped on save — indistinguishable from a bug. The select now omits `admin` for anyone who
cannot grant it, with one exception: when editing a user who already holds `admin`, the option stays so
the form displays their current role correctly (and keeping it is a no-op server-side, since the permit
drops the unchanged-by-a-non-admin grant).

## D4. Per-site admin is a separate, larger change

H10's other residual — `admin?` being a global, cross-site string rather than per-site — is not addressed
here. A user's `role` is a single global column with no per-`(user, site)` storage, so per-site admin
would need a schema/model change and touches the authorization root (`Ability`) and a public predicate;
it is a redesign, not a permit fix, and the maintainer has treated it as by-design.

## D5. The role permit was only half the boundary — credentials are the other half

Gating the role alone does not meet the goal ("`:manage, :users` is not a path to controlling admin
accounts"). The same holder could reset an admin's password through `#update` or the `#updated_ajax`
endpoint and sign in as them, or repoint the admin's email and hijack a password-reset link — both are
paths to superadmin that leave the role restriction moot. A companion predicate,
`UserDecorator#may_edit_credentials?(other_user)`, returns `admin?` when the target is an admin and `true`
otherwise (no self-check needed: a non-admin can never be an admin target). `#user_params` drops
`password`/`password_confirmation`/`email`/`username` for a non-admin editing an admin — the same
drop-and-fail-safe the role permit uses (D1) — and `#updated_ajax`, which bypasses `user_params`, refuses
with `403`. Self-edits and non-admin targets are untouched, so a manager keeps every legitimate power. The
form mirrors this (D3): those inputs are disabled and the change-password action hidden when unusable.

## D6. A role parameter is a scalar

`#user_params` reads `role` outside the permit list (so it can gate the value), which means a non-scalar
`user[role][x]` param arrives as an unpermitted `ActionController::Parameters`; assigning it during
`update` would raise `ActionController::UnfilteredParameters` and `500` the request. The value is coerced
to `nil` unless it `is_a?(String)`, matching the scalar slug the form emits — malformed input is ignored,
not fatal.
