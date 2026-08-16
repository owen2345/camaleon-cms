## Why

`MediaController#crop` writes any same-site user's avatar from `saved_avatar` behind the media
permission alone (`authorize! :manage, :media`). PR #1267 closed the cross-tenant boundary by
resolving the target through `current_site.users`, but the object-level boundary was left open: a
role holding only `:manage, :media` can still overwrite another same-site user's avatar — including
an administrator's. The twin write in `UsersController#update` already requires `:manage, :users`
for a non-self target; `crop` is a second, unlocked door to the same `set_meta('avatar')` write.
This is the remaining half of the reporter's object-level authorization finding (the tenancy half
shipped in #1267), and it blocks the pending CVE.

## What Changes

- `MediaController#crop` SHALL authorize the `saved_avatar` target before performing any
  upload/crop work: a caller may always write their **own** avatar (the media permission already
  required suffices), but writing **another** user's avatar SHALL require `:manage, :users`.
- The authorization decision SHALL be derived from the `saved_avatar` parameter **before** the
  target is resolved, so a denied caller cannot use the response to tell whether a same-site user
  exists (no existence oracle) — mirroring `UsersController#profile`.
- The existing tenancy behavior is preserved: a `saved_avatar` id the current site does not own
  remains a nil-safe no-op for an authorized caller.
- No new permission is introduced. The check reuses the existing `:manage, :users` capability, which
  already governs cross-user avatar writes via `UsersController#update`.
- Admins are unaffected (`can :manage, :all` satisfies the check). A plain crop with no
  `saved_avatar` is unaffected.
- **BREAKING (for a narrow, non-default role)**: a role granted `:manage, :media` **without**
  `:manage, :users` can no longer set other users' avatars through `crop`. The current UI does not
  emit `saved_avatar` for a cross-user target (the profile/user form routes avatar changes through
  `UsersController#update`), so no shipped flow regresses; only a caller exercising the endpoint
  directly is affected.

## Capabilities

### New Capabilities

_None._ The object-level rule attaches to the existing avatar-crop capability rather than
introducing a new one.

### Modified Capabilities

- `avatar-target-tenancy`: extend the crop avatar target's guarantees from the tenancy boundary
  alone to tenancy **plus** object-level authorization. The existing "a same-site user's avatar
  still updates" scenario is qualified (the caller must be the target or hold `:manage, :users`),
  and a new requirement adds the self-vs-other authorization, the pre-resolution (oracle-safe)
  decision, and the authorize-before-crop ordering.

## Impact

- **Code**: `app/controllers/camaleon_cms/admin/media_controller.rb` (`#crop`) — an early per-target
  authorization check. ~3 lines; no change to the upload/crop pipeline or the plain-crop return.
- **Denial behavior**: `authorize!` raises `CanCan::AccessDenied`, handled by
  `AdminController` as a flash error + redirect to the dashboard (302), leaving the avatar untouched.
- **Specs**: [`spec/requests/security/crop_avatar_target_scope_spec.rb`](../../../spec/requests/security/crop_avatar_target_scope_spec.rb)
  example "still sets the avatar for a user in the current site" currently asserts the vulnerable
  behavior and SHALL be revised to assert denial. A reproducing test (media-only caller denied for a
  non-self same-site target, avatar unchanged) is added, plus coverage for self-allowed and
  `:manage, :users`-allowed. The self case in `crop_spec.rb` and the admin/self cases in
  `admin_destructive_get_verbs_spec.rb` remain green.
- **Related specs (cited, not modified)**: `security-capability-gating` (reuse an existing
  permission rather than add one; the same action reached by a different path must have the same
  authorization outcome) and `profile-authorization` (the self-vs-other, pre-resolution model this
  mirrors).
