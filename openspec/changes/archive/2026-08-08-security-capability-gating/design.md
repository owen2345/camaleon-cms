# Design: security-capability-gating

## Why a convention capability, not just docs

A doc records the rule; a spec makes a proposal that violates it visible at review time. The
`ecosystem-plugin-bindings` capability does the same for external contracts — a requirement a later
change is measured against. Here the "conformant examples" are the four permissions that already
implement the rule, and the governance requirement is what a new security-sensitive action is checked
against before it merges.

## The three parts of the rule

**Admin bypass.** `Ability#initialize` answers `can :manage, :all` for the `admin` role before any
role meta is read, so administrators satisfy every check without holding the permission. This is why a
new permission needs no admin backfill and why the admin role's checkbox for it reads unchecked but
effective.

**Default-off for everyone else.** The permission lives in `UserRole::ROLES[:manager]` (site-wide) or
`ROLES[:post_type]` (per type), with `color: 'danger'`. Role seeding writes manager/post-type metas
only for the roles that should have them — never the new key onto a non-admin role — so an upgraded
install reads the absent key as not-granted and needs no migration. The one wrinkle is the Editor
post-type seeding, which grants every post-type key; a genuinely dangerous post-type permission needs
an explicit `next if key == '<key>'` skip there, as `post_content_unfiltered_html` has.

**Fail closed.** The predicate mirrors `Post#trusted_for_unfiltered_html?` and
`UploaderContentSecurity#cama_trusted_for_unfiltered_upload?`: read `CurrentRequest.user` and
`CurrentRequest.site`, return false if either is blank, otherwise ask `CamaleonCms::Ability`, and
`rescue StandardError` to false. The blank-context branch is what makes rake tasks, jobs and the
console untrusted by default; the rescue is what turns malformed role meta into a refusal, not a 500.

## Authorization, not a proxy

The requirement that the gate be an authorization check — not a filesystem path, an output filename, a
client-supplied flag, or a network location — is the #1228 lesson stated as a rule. A path-based upload
exemption was bypassable because the output name is caller-supplied; the fix was to ask *who*, not
*where*. The same reasoning rejects "trust a `before_upload` handler by definition" for N2: a handler
that swaps the scanned bytes is re-checked against the permission, not waved through because it ran.

## What this does not do

It does not change the four existing permissions, retrofit any check, or implement N2. It is the rule
plus its enforcement seam. Retrofitting an existing ad-hoc, fail-open or proxy-gated check is a
per-finding fix that cites this capability when it lands — starting with N2.
