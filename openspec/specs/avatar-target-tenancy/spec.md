# avatar-target-tenancy Specification

## Purpose
When the media crop flow writes a user's avatar from `saved_avatar`, the target user must be
resolved within the caller's tenancy, so a media manager cannot write — or probe the existence of —
a user outside the sites they administer.
## Requirements
### Requirement: The crop avatar target is resolved within the current site

`MediaController#crop` SHALL resolve the `saved_avatar` target through `current_site.users` and write
the avatar only when a matching user is found. Because `current_site.users` yields all users in
shared-users mode and only the site's own users otherwise, a `saved_avatar` id the current site does
not own SHALL be a no-op — no avatar written, no error raised, no existence oracle.

Tenancy resolution is necessary but not sufficient: a resolved same-site target is written only when
the caller is also authorized to write it (see "The crop avatar target is authorized as self or by a
user manager"). The scenarios below describe the resolution behavior for a caller already authorized
to write the target.

#### Scenario: A foreign user's avatar is not written

- **WHEN** users are not shared across sites and a caller authorized to manage users crops with
  `saved_avatar` naming a user of another site
- **THEN** that user's avatar is unchanged and no error is raised

#### Scenario: A same-site user's avatar still updates

- **WHEN** a caller authorized to write the target (the target is the caller, or the caller holds
  `:manage, :users`) crops with `saved_avatar` naming a user the current site owns
- **THEN** that user's avatar is set to the cropped image

### Requirement: The crop avatar target is authorized as self or by a user manager

`MediaController#crop` SHALL authorize the `saved_avatar` target before performing any upload or crop
work. A caller MAY write their own avatar with only the media permission the endpoint already
requires. Writing any other user's avatar SHALL require `:manage, :users`; a caller without it SHALL
be denied and the avatar SHALL be left unchanged. Administrators satisfy the check through
`can :manage, :all`.

The authorization decision SHALL be derived from the `saved_avatar` parameter alone and SHALL be made
before the target is resolved, so the response to an unauthorized caller does not depend on whether
the named user exists — no same-site existence oracle. Because the check precedes the upload and
crop, an unauthorized avatar request performs no file work.

This reuses the existing `:manage, :users` capability — the same capability that already governs
cross-user avatar writes through `UsersController#update` — rather than introducing a new permission,
so that the same write reached by a different path yields the same authorization outcome
(`security-capability-gating`).

#### Scenario: A caller writes their own avatar

- **WHEN** crop is called with `saved_avatar` naming the calling user and the caller holds
  `:manage, :media`
- **THEN** the caller's avatar is set to the cropped image, without `:manage, :users` being required

#### Scenario: A user manager writes another user's avatar

- **WHEN** a caller holding `:manage, :users` crops with `saved_avatar` naming another user the
  current site owns
- **THEN** that user's avatar is set to the cropped image

#### Scenario: A media-only caller is denied another user's avatar

- **WHEN** a caller holding `:manage, :media` but not `:manage, :users` crops with `saved_avatar`
  naming a same-site user who is not the caller
- **THEN** the request is denied, no avatar is written, and no upload or crop is performed

#### Scenario: Denial does not reveal whether the target exists

- **WHEN** a caller not authorized to manage users crops with a `saved_avatar` that is not their own —
  whether it names an existing same-site user, a user of another site, a nonexistent id, or a
  non-numeric value
- **THEN** the request is denied identically in every case, disclosing no difference between them
- **AND** the target is not queried before the denial

#### Scenario: A plain crop is unaffected

- **WHEN** crop is called with no `saved_avatar`
- **THEN** the image is cropped and its url is returned, with no avatar write and no
  user-management check

