# Scope the crop avatar target to the current site (Low)

## Why

`media#crop` set a user's avatar with an unscoped `CamaleonCms::User.find(params[:saved_avatar])`.
When `users_share_sites` is false, that let a media manager on one site write the avatar of a user
belonging to another site, and — because `find` raises on a miss — probe which user ids exist across
all sites (an existence oracle plus a 500 on a bad id). Audit Low.

### Triage verdict: legit

Reproduced in `spec/requests/security/crop_avatar_target_scope_spec.rb` (with `users_share_sites`
false): before the fix, cropping with `saved_avatar` naming a foreign user rewrites that user's
avatar; after it, the write is a no-op.

## What Changes

- The avatar target resolves through `current_site.users.find_by(id: ...)` and is written only when
  found. `current_site.users` returns all users in shared mode and the site's own users otherwise,
  so the fix respects the deployment's `users_share_sites` setting, closes the cross-tenant write and
  the existence oracle, and no longer 500s on a bad id.

## Notes for upgraders

- None. In the default shared-users mode every user stays reachable exactly as before.
