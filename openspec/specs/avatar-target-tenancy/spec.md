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

#### Scenario: A foreign user's avatar is not written

- **WHEN** users are not shared across sites and crop is called with `saved_avatar` naming a user of
  another site
- **THEN** that user's avatar is unchanged and no error is raised

#### Scenario: A same-site user's avatar still updates

- **WHEN** crop is called with `saved_avatar` naming a user the current site owns
- **THEN** that user's avatar is set to the cropped image

