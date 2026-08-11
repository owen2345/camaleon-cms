## Why

`Admin::UsersController` guards its actions with `validate_role`, whose self-exemption skips the
`:manage, :users` check when the resolved `user_id` is the caller's own id. That exemption is
meaningful only for member actions that act on a single target user, but it also runs on the collection
actions `index`/`new`/`create`, which have no target — so any authenticated caller can inject their own
id to bypass the check. `GET /admin/users?user_id=<own>` returns the full user table (every email;
every user on every site under the shipped `users_share_sites: true`), and
`POST /admin/users?user_id=<own>` creates an account, also bypassing the `permit_create_account`
registration gate. This is audit finding **H7**. The #1214/#1236 target-resolution work hardened the
member routes but did not consider the collection routes, which the `user-target-resolution` capability
never covered.

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A. Reproduced against the unfixed branch: signed in as a `client`
(no `:manage, :users`), `GET /admin/users?user_id=<own>` returned `200` with the user table and
`POST /admin/users?user_id=<own>` changed `User.count` from 3 to 4. The control (the same requests with
no `user_id`) is already denied, and both succeed for a caller holding `:manage, :users` — so the
injected `user_id` is the bypass. The reproduction spec fails against the unfixed branch.

## What Changes

- The `validate_role` self-exemption now applies only to the member actions that resolve a single
  target user (`SELF_TARGET_ACTIONS = show/edit/update/destroy/impersonate/updated_ajax`). Every other
  action — the collection actions, and any future one — requires `:manage, :users`.
- Adds a request spec covering the collection-action denial (index/new/create with an injected
  `user_id`), the no-injection control, the manager-can-still-use-them case, and a member self-service
  regression guard (a non-manager changing their own password via `updated_ajax`).

## Out of scope

- **Role escalation by a legitimate user-manager.** A caller who *does* hold `:manage, :users` can still
  mint an account with `role: 'admin'`; that is the H10 policy question (`:manage, :users` is
  effectively superadmin), tracked separately.
- **The member self-exemption.** Left exactly as-is — a caller managing their own record, notably a
  self password change via `updated_ajax`, is unchanged, and the existing member/target-resolution
  specs still pass. See `design.md`.
