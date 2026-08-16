## Context

See [proposal.md](proposal.md) for motivation. The relevant current state:

The user avatar meta has exactly two write paths in the application:

```
   users#update  (meta[:avatar])            media#crop  (saved_avatar)
   GATE: validate_role                       GATE: :manage, :media only
     → self OR :manage, :users  ✓              → no per-target check     ✗
        the FRONT door (locked)                    the SIDE door (open)
```

`UsersController#update` already requires `:manage, :users` for a non-self target (via
`validate_role` / `SELF_TARGET_ACTIONS`). `MediaController#crop` reaches the identical
`set_meta('avatar')` write behind the media permission alone. PR #1267 (spec `avatar-target-tenancy`)
scoped the target through `current_site.users`, closing the cross-tenant boundary but leaving the
same-site, cross-user boundary open.

`UsersController#profile` already implements the exact self-vs-other, pre-resolution model this change
needs (spec `profile-authorization`, [users_controller.rb:27](../../../app/controllers/camaleon_cms/admin/users_controller.rb)):

```ruby
authorize! :manage, :users if user_id.present? && user_id.to_i != cama_current_user.id
```

## Goals / Non-Goals

**Goals:**
- Bring `media#crop`'s avatar write to the same authorization altitude as `users#update`.
- Preserve the self-service path (a caller writing their own avatar) and the tenancy no-op.
- No existence oracle; no wasted upload/crop work on a denied request.

**Non-Goals:**
- No new permission, no role-meta migration, no data backfill.
- No change to the plain-crop path (no `saved_avatar`), the upload/crop pipeline, or the return body.
- Not touching `users#update` — it already enforces the boundary.

## Decisions

**1. Reuse `:manage, :users`; do not add a new permission.**
`security-capability-gating` requires that where an existing permission's holders already possess the
capability, a change extend that permission rather than add one (a new permission would revoke the
capability from installs that already granted the old one). `:manage, :users` holders can already set
any same-site user's avatar via `users#update`, so it is the correct gate. A new default-off
`media_edit_others_avatar` permission was considered and rejected on that rule; it would also misread
the model — the default-off-permission remedy is for capabilities with *no* existing gate, and this
one is governed today at the front door.

**2. Keep the self-exemption (chosen with the user).**
`saved_avatar == current_user.id` is allowed with only `:manage, :media`. This matches the reporter's
boundary #1 and the self-exemption `users#update`/`profile` already grant. The alternative — require
`:manage, :users` for *any* `saved_avatar`, including self — was rejected: it would stop a media
manager from editing their own avatar through this endpoint and contradicts the report.

**3. Authorize from the parameter, before resolving the target.**
The check compares `saved_avatar` to `current_user.id` and calls `authorize! :manage, :users` *before*
any `current_site.users.find_by`. A media-only caller passing any non-self id — same-site, foreign,
nonexistent, or non-numeric — is denied identically, so the response is not a same-site existence
oracle. Resolving first and authorizing only when a record is found was rejected for exactly that leak
(the failure mode `profile-authorization` documents).

**4. Authorize early, before the upload/crop.**
The check sits near the top of `crop`, after the URL-error guard and before `cama_tmp_upload`. This is
the reporter's explicit request and avoids doing (and writing to disk) the crop for a request that
will be denied. The alternative — run the crop, then silently skip the avatar write when unauthorized
— was rejected: it wastes work and returns an ambiguous 200 for what is really a denial.

**5. Avatar is not a credential, so `may_edit_credentials?` does not apply.**
`:manage, :users` is sufficient to write another user's avatar, including an admin's — exactly as
`users#update` already permits (its `user_meta_params` permits `:avatar` for any target gated only by
`validate_role`). The admin-only `may_edit_credentials?` restriction governs passwords and recovery
identifiers, not profile meta. Applying it here would make `crop` *stricter* than the front door and
diverge the two paths again. This is a deliberate consistency choice, not an oversight.

**6. Denial is the endpoint's existing shape.**
`authorize!` raises `CanCan::AccessDenied`, which `AdminController` turns into a flash error + redirect
to the dashboard (302). No new error handling; identical to how the endpoint already denies a caller
lacking `:manage, :media`.

## Risks / Trade-offs

- **A `:manage, :media`-only role can no longer set *other* users' avatars via `crop`.** → This is the
  intended fix. No shipped UI regresses: the profile/user form routes avatar changes through
  `users#update`, and the current profile JS never posts a cross-user `saved_avatar`. Documented as a
  narrow breaking change in the proposal. `:manage, :users` holders and admins retain the ability.
- **Array-shaped `saved_avatar[]`.** → Fails closed: `to_s` on an array never equals
  `current_user.id`, so it requires `:manage, :users`. Optionally coerce to a scalar (as
  `users_controller#user_id_param` does) — hardening, not correctness, since the behavior is already
  fail-safe.
- **The existing cross-site test changes mechanism.**
  [`crop_avatar_target_scope_spec.rb`](../../../spec/requests/security/crop_avatar_target_scope_spec.rb)
  uses a media-only caller; its foreign-target example now *denies* (redirect) rather than silently
  no-ops, and its same-site example must flip to assert denial. The `avatar unchanged` assertions still
  hold. To keep demonstrating the tenancy no-op itself (authorized caller + foreign id → nil, no
  error), add an example whose caller holds `:manage, :users`.

## Migration Plan

No migration. Deployment is the controller change plus spec/test updates. Rollback is a straight
revert. Upgraded installs already read an absent `:manage, :users` as not-granted, so no role meta is
seeded or backfilled. The reproducing test (media-only caller denied a non-self same-site target,
avatar unchanged) is required for the security fix and is added alongside the change.

## Open Questions

- Whether to also coerce `saved_avatar` to a scalar (the array trade-off above). Deferrable: the current
  behavior already fails closed, so resolving this later changes neither the specs nor the approach.
