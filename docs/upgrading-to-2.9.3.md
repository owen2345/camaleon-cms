# Upgrading to 2.9.3

Version `2.9.3` is a large security release. It closes the vulnerabilities found by a full
regression audit of `2.9.2..master` and by several external reports, and it changes a number of
behaviours you must plan for. This guide is the **operator and upgrader runbook**: the actions to
take, the behaviour changes you and your visitors may notice, and the notes for theme and plugin
developers.

Each change is described in full in [CHANGELOG.md](../CHANGELOG.md), where **breaking changes** are
flagged per entry. This guide collects everything an upgrader needs to *do* or *know*; the changelog
is the per-PR record.

Because the security model is *reject on save, never rewrite*, nothing you already stored is
modified by upgrading. Content and uploads that predate the new rules are left exactly as they are —
which is why this release ships read-only **audit** tasks that show you what today's rules would
refuse, and a few **repair** tasks for specific situations.

## At a glance — what applies to you

| If your install… | Do this |
| --- | --- |
| **Any install** | Run the two read-only audit scans; clear `public/tmp/`; `bundle update camaleon_cms` |
| Runs **scripted/automated remote installs** | Set `CAMALEON_SETUP_TOKEN` before running the installer |
| Still uses the **historical default admin password** | Rotate it |
| Stores uploads on **AWS / S3** | Run `repair_private_upload_acls` |
| Has non-admin roles that set **other users' avatars** | Grant them `:manage, :users` — the `media` permission alone no longer suffices |
| Is **multi-site** | Run `rehome_cross_site_field_groups`, then review each site's field-group list |
| Configures a **namespaced `user_model`** (e.g. `Admin::User`) | Run `demodulize_user_field_groups` |
| Runs in **production** | Point `Rails.cache` at a shared store (Redis/memcached) for the login throttle |
| Built **Site custom-field groups by hand** | Run `backfill_site_field_group_objectid` |
| Deleted users while tracking **pre-release `master`** | Run `reassign_orphaned_comments` |

Beyond these actions, review **[Behavior changes you may observe](#behavior-changes-you-may-observe)**
and, if you maintain a theme or plugin, **[Notes for theme & plugin developers](#notes-for-theme--plugin-developers)**.

## How to run the tasks in this guide

Every task below ships with the gem and runs from your **host application's root**, against your
configured environment. The commands are shown for **production** — change or drop `RAILS_ENV` to
target another environment:

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:security:scan_content
```

Either runner works — `bundle exec rake <task>` or `bin/rails <task>`. Each task prints its progress
to the terminal and a one-line summary to the Rails log.

---

## Installer setup token (BREAKING for scripted installs)

The first-run web installer now requires a **setup token** for **remote** requests, so it cannot be
completed by an anonymous visitor who reaches a freshly deployed app before the operator does.

- **Local installs are exempt** — a request from the local host (installing on `localhost`, or over an
  `ssh -L` tunnel) needs no token, because local access already proves host access.
- For a remote install, provide the token via `CAMALEON_SETUP_TOKEN` in the environment, or read the
  auto-generated value from `tmp/camaleon_setup_token` (also logged on first access) and enter it in the
  installer form.
- Automated or scripted **remote** installs that drive the installer must now supply
  `CAMALEON_SETUP_TOKEN`.
- The token is required only while no site exists; once installed, the installer is closed as before.
- The loopback exemption uses `request.local?`, which trusts your reverse proxy (if any) to forward the
  real client IP via `X-Forwarded-For` — standard configuration. A proxy that strips it would let a
  remote request appear local, so set `CAMALEON_SETUP_TOKEN` in that case as defense in depth.

See [docs/installation.md](installation.md) for the full flow.

## Default administrator no longer uses a known password

Previously a new site was provisioned with the administrator `admin` / `admin123`, and the installer's
confirmation page displayed those credentials to anyone who visited it.

### What changed

- New installs mint the `admin` account with a **randomly generated password**, shown **once** on the
  installer confirmation page (with a copy button) and never persisted where it can be read back.
- The confirmation page is now reachable only by the operator who just completed setup, not by anonymous
  visitors.
- A newly provisioned administrator is required to change its password on first sign-in.

### Recommended action for existing installs

Upgrading does **not** rewrite existing accounts. If your site was installed before this release and its
administrator still uses the default password, **rotate it now** — either from the admin profile screen,
or from a Rails console on the server:

```bash
RAILS_ENV=production bundle exec rails console
```
```ruby
u = CamaleonCms::User.find_by(username: "admin")
u.update(password: "your-new-password", password_confirmation: "your-new-password")
```

The disclosure itself (the credentials showing on the installer's confirmation page) is closed for all
installs by this release, regardless of whether you rotate.

## Administrator password reset restored

On Rails 7.1+, `has_secure_password` generates a `password_reset_token` method that shadowed
Camaleon's same-named database column: the mailer emailed one value while the reset lookup matched
the other, so every emailed reset link dead-ended on "URL incorrect" even though the user was told
the email was sent. This release aligns both sides on the stored column (which behaves identically on
Rails 6.1–8.1), and makes reset links single-use, time-bounded, and confined to the account's own
site.

- **Any reset links already outstanding at upgrade time are invalidated** and must be re-requested —
  they were non-functional in practice anyway.
- No schema change; no action beyond re-requesting a reset if one was in flight.

---

## Post-upgrade maintenance tasks

### Audit tasks — read-only, recommended for every install

These change nothing. They reuse the real save-time scanners, so their report can never disagree with
what an upload or a save of the same bytes would be told today. Run them, then review and clean up
whatever they list **by hand** — content and uploads are never rewritten under this project's security
model. A finding is **not** by itself evidence of compromise: the rules are newer than your data, so
anything uploaded or authored legitimately under the old rules is listed too.

**List stored content that would now be rejected** (post content and gated custom-field values —
editor, `field_attrs`, and URL field types):

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:security:scan_content
```

**List stored media files that would now be rejected** (public and private uploads, scanned exactly
as an upload would be):

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:security:scan_uploads
```

### Repair tasks — run only if the row in the table applies to you

Each writes only the narrow column named below; none deletes anything.

#### Re-apply the private ACL to S3 uploads — AWS/S3 installs

Uploads stored under the private prefix before the private-ACL fix kept a `public-read` ACL, leaving
them world-readable at a guessable `s3://bucket/private/<name>` URL. This task sweeps every AWS-backed
site's private prefix back to an owner-only ACL. Public uploads are untouched.

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:repair_private_upload_acls
```

If your uploader hook configures an `inner_folder` (so the private root is `<inner_folder>/private/`),
name it — a plain `private/`-prefix sweep would miss those objects:

```bash
RAILS_ENV=production CAMA_S3_INNER_FOLDER=<folder> bundle exec rake camaleon_cms:repair_private_upload_acls
```

#### Re-home cross-site custom field groups — multi-site installs

A custom field group whose owning site (`parent_id`) differs from the site owning its placement renders
on the placement's site while staying invisible in that site's own field-group list. This task moves each
such group to the site it actually renders on, so its administrators can see and delete it. Nothing is
deleted; a group whose placement target no longer exists is skipped.

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:rehome_cross_site_field_groups
```

**After it runs, review the field-group list of any site that gained a group** — a group that appears
newly is one that was already rendering on that site's pages.

#### Backfill `objectid` on hand-built Site field groups — rare

Site field groups saved with a `NULL` `objectid` are hidden by the placement-scoped read on the site
settings page. No shipped code path creates such rows — only an install that built site groups by hand
(bypassing `add_custom_field_group`) has anything to repair. This backfills the missing `objectid` with
the owning site's id.

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:backfill_site_field_group_objectid
```

#### Re-key user field groups — namespaced `user_model` installs

If your host app configures a namespaced user model (e.g. `user_model: 'Admin::User'`), user custom
field groups written through 2.9.2 were stored under the qualified name, which the current association
scope cannot see — so those fields disappear from the user edit page. This re-keys them to the
demodulized name the scope reads. It is idempotent and a **no-op** on engine-default or top-level `User`
installs.

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:demodulize_user_field_groups
```

> **Rollback note:** after this task runs, rolling back to 2.9.2 hides those groups on the user edit
> page until you re-upgrade (the data is intact). See [Rollback notes](#rollback-notes).

#### Reassign orphaned comments — pre-release `master` trackers only

Applies only if you deleted users while running a build **between** 2.9.2 and this release, where a
regression could null a *registered* user's comment author. It reassigns comments whose user no longer
exists to the owning site's anonymous user; genuine guest comments are left alone, and it is idempotent.
A clean `2.9.2 → 2.9.3` upgrade does not need it, and running it anyway is harmless. (Deleting a user no
longer aborts when one of their comments has an unresolvable post; such comments are skipped and reported
by this task.)

```bash
RAILS_ENV=production bundle exec rake camaleon_cms:reassign_orphaned_comments
```

---

## Other operator actions

### Clear the upload staging directory

Earlier versions could leave a rejected upload in the web-served staging directory (`public/tmp/<site_id>/`).
On a long-running 2.9.2 install it may already hold planted payloads. Clear it once during your upgrade
window (ideally with the app stopped):

```bash
rm -rf public/tmp/*
```

This directory only ever holds transient upload staging files, so clearing it is safe.

### Pick up the dependency bumps

The `cama_contact_form` floor was raised to `~> 0.1.12` (where the plugin-side HTML-injection fix lives),
and several transitive gems received security patches. Nothing to add to your `Gemfile`:

```bash
bundle update camaleon_cms
```

### Use a shared cache store for the login throttle (production)

Admin-login brute-force protection now counts failed attempts **per client IP** in `Rails.cache`. In
production, point `Rails.cache` at a store shared across your workers/processes (Redis or memcached) so
the throttle holds cluster-wide; a per-process store weakens it. Behind a shared egress IP a captcha may
appear after enough failures from anyone on it — tune `max_try_attack` and `login_lockout_attempts` to
taste.

### No action needed: front_cache

Existing `front_cache` page-cache entries are keyed under the old scheme and simply regenerate once after
upgrade.

### Do not leave `CAMALEON_SKIP_URL_VALIDATION` set

`ENV['CAMALEON_SKIP_URL_VALIDATION']` is an operator escape hatch that bypasses **all** upload-URL
validation (scheme, host, SSRF/link-local, path traversal, HTML sanitization). It is for trusted,
isolated environments only — leaving it set in production removes the SSRF and open-fetch protections
around `crop`/`crop_url`.

---

## Behavior changes you may observe

No action required for these on their own — they describe what changed for authors, visitors, and
external callers so a surprise later reads as expected.

### Content & editing

- **Untrusted content is refused on save, not sanitized.** A post or custom-field save that previously
  went through with markup stripped now fails with a validation error until the author removes the markup
  (or is granted the permission). Stored content is never rewritten — run the audit scans to see what
  today's gates would refuse. `data-*`/`aria-*` attributes are now accepted (previously stripped), but a
  value that *decodes* to markup is still refused. Content beyond a generous size bound (a few MB) is
  refused with a distinct "too large" error. The theme-DSL helper `the_content` no longer sanitizes at
  render either — it emits stored content verbatim, as the templates always did.
- **Content from the 2.9.1–2.9.2 sanitize-on-save era may render double-encoded once** (e.g. `&amp;`
  shown literally). There is no repair task — a blanket re-encode cannot tell a legitimately-authored
  `&amp;` from a sanitize-era artifact — but each affected field self-heals the next time it is edited
  and saved.
- **A slug containing HTML metacharacters stored before the upgrade now renders as an inert, escaped
  link** instead of executing. Ordinary slugs are byte-identical.
- **A post whose status is not one of the five canonical values now renders as visible escaped text** —
  which is how you spot a row poisoned before the upgrade. Non-canonical statuses are supported
  deliberately, so nothing is rejected on write and no data is rewritten; legitimate data is byte-identical.
- **Slug uniqueness is enforced again on Rails 7.0+.** A save that duplicates a slug already held by any
  non-draft, non-trashed post of the same site — the scope is site-wide, across post types and parents —
  or that creates a looping page hierarchy, fails validation again. Records duplicated while the validator
  was inert are not rewritten; they surface the error the next time they are edited.

### Sessions & login

- **Logging out ends the user's sessions on all devices** (the auth token is per-user). A full logout
  while impersonating leaves the impersonated user's own sessions alone. Changing your password re-issues
  the cookie with the same `HttpOnly`/`Secure` hardening.
- **Bookmarked `?post_password=` links no longer unlock a protected post** — visitors enter the password
  in the prompt instead. Themes that override the `visibility_post` password form should adopt the POST
  form markup.
- **Admin login is throttled per client IP.** Behind a shared IP a captcha may appear after enough
  failures from anyone on it. Captchas are now single-use — render a fresh image per attempt. (See also
  the shared cache-store action above.)

### Admin routes & external integrations

- **Destructive admin actions no longer answer GET.** External links or scripts that hit the converted
  admin paths over GET stop working — use PATCH/POST/DELETE with a CSRF token. `GET /admin/logout` still
  works (it now shows a one-click confirmation page), so themes that link it keep functioning.
- **Nav-menu item delete now requires DELETE, and `media/crop` requires POST** — with a CSRF token.
- **External scripts POSTing to `/admin/media/upload` must now send the CSRF token** (the
  `authenticity_token` field or the `X-CSRF-Token` header). First-party uploaders are already updated.

### Media & uploads

- **Uploads by anyone but an administrator are scanned by content type, whatever their source** —
  including files already stored under `public/`, so re-cropping an existing file is scanned again.
- **Markup uploads (SVG, HTML, XML) are parsed and refused only if they carry active content** —
  scripts, `on*` event handlers (matched by shape, not a fixed list), dangerous URI schemes, or other
  executable/interactive elements. A document that merely displays escaped markup (`&lt;script&gt;`)
  passes, because the parser reads it as text — which is what a browser does.
- **Executable scripts (`.js`, `.mjs`, `.cjs`, `.wasm`, `.swf`) are refused outright** for these
  users: no scan can reach a verdict on JavaScript, so the type is gated rather than scanned.
- **Grant `media_unfiltered_upload`** ("Allow unscanned media uploads", Manager Permissions) to a role
  that must store unscanned or script uploads — no default role but `admin` holds it, and it skips
  scanning entirely.

### Admin & editing workflow

- **Each editor keeps a private autosave buffer per post**, so the admin drafts list can show one draft
  per editing user; any successful save of a post removes all of its buffers. Roles holding only
  `edit_other` can now autosave posts they can edit but not author.
- **Theme settings ignore unregistered slugs.** Values submitted for slugs that are not registered theme
  fields are no longer persisted; registered fields are unaffected.
- **Adding a plugin or theme folder now needs a server restart before it is discovered** — the
  Plugins/Themes admin index no longer rescans the filesystem on each view. Restart the app after
  dropping in a new plugin/theme directory.
- **Posts of a deleted user with no surviving admin now keep `user_id` NULL** (2.9.2 left a dangling id);
  display already handled both.
- **Setting another user's avatar via the media crop now requires `:manage, :users`.** A role with only
  the `media` permission can still set its own avatar, but no longer another user's (including an
  administrator's) — grant `:manage, :users` to a role that manages other users' avatars.

---

## Notes for theme & plugin developers

### Public API changes

- **`sort_by_field` honors only the sort direction.** The leading token of the `order` argument is
  matched against `asc`/`desc` case-insensitively — padded or modifier-bearing directions such as
  `'DESC NULLS LAST'` keep their direction, though the modifier itself is dropped — and anything else
  falls back to ascending. A caller that passed additional raw SQL through `order` must use `reorder`
  directly instead.
- **`site.get_field_groups` is narrower.** It now returns only the groups placed on the site, matching
  its documented contract. For "every group in this site", use `site.custom_field_groups` (unchanged).
- **`cama_pluralize_text` returns an `ActiveSupport::SafeBuffer` when given one.** It propagates the
  safeness of its input and never adds it, so an unsafe input still yields an unsafe result.
- **`the_title` still escapes its output.** The contract that themes and plugins rendering titles through
  `raw` depend on is unchanged. Theme authors need change nothing.
- **`PostDecorator#the_status`, `CustomFieldGroup#get_caption`, and `TermTaxonomyDecorator#the_status`
  now return an `ActiveSupport::SafeBuffer`.** Output for legitimate data is byte-identical, so a theme
  matching on the rendered status label or field-group caption is unaffected.
- **`update_field_value` now applies the scan-and-reject gate** — a dangerous value is refused there
  instead of stored.

### Constants & modules moved or removed

- **`SUSPICIOUS_PATTERNS` and the unsafe-event-handler constants now live in
  `CamaleonCms::ContentSecurity`**, not `CamaleonCms::UploaderHelper`. A plugin referencing the old path
  gets a `NameError`; update the constant path.
- **`ActiveRecordExtras` is removed**, and with it `update_or_create`, `update_or_create!`, and
  `assign_or_new`. Use the Rails idiom instead:
  `Model.find_or_initialize_by(lookup_attrs).tap { |r| r.assign_attributes(extra_attrs); r.save }` (or
  `save!`).

### Hooks & extension points

- **Off-site redirects after login/registration are dropped to the safe default.** Restore one by
  trusting the destination host: set the `redirect_allowed_hosts` site option (comma-separated), or
  append to it from the new `safe_redirect_hosts` hook (`r[:hosts] << 'checkout.stripe.com'`). For a
  fully-dynamic destination, an `after_login`/`user_registered` hook can set `r[:allow_external_redirect]`
  to vouch for its `redirect_to`/`redirect_url`. `http`/`https` only in both cases; a caller-supplied
  `return_to` is never opted in this way.
- **A sign-in now starts a fresh session** (`reset_session`). Plugins that place data in the session
  during a `user_before_login`/`after_login` hook must move it elsewhere (a cookie, or after the redirect).
- **`user_before_register` now fires during registration** (previously a silent no-op), after the register
  captcha passes; a handler can veto a signup by setting `r[:stop_process]`.
- **Solving a captcha no longer resets the login under-attack counter by itself** — it clears only when
  the protected action succeeds. Downstream callers of `captcha_verify_if_under_attack` should call
  `cama_captcha_reset_attack(key)` after their own success (the bundled login flows already do).

### Uploads (server-side callers)

- **Plugins, jobs and imports may pass `allowed_roots:`** to `upload_file`/`cama_tmp_upload` to stage
  files under `Rails.root/tmp`, `storage/`, or a mounted share. It applies to that call only and must
  come from application code — a request parameter cannot widen the roots.
- **SVG event handlers (`onbegin`/`onend`/`onrepeat`), `script`, `foreignObject` and `handler` remain
  rejected**; only the `animate`/`set` elements themselves are allowed.
- **Trusted server-side code can bypass content gating per record** with `post.unfiltered_content!`
  before save (imports, seeds, plugin pipelines). It has no `=` writer, so it is not mass-assignable and
  request parameters cannot set it. Admins and roles holding `post_content_unfiltered_html` still store
  raw HTML; the Editor default is excluded.

### Cross-site custom field groups (multi-site)

- **Submitting a placement the current site does not own is now refused** with a form error. Classes with
  a single legal target — `Site`, the configured user model, and models registered through the
  `custom_field_custom_models` hook — are validated against the current site's id rather than an allow-list
  of class names, so plugins contributing custom models keep working. The read paths are unchanged. (The
  repair task for already-injected groups is under [maintenance tasks](#re-home-cross-site-custom-field-groups--multi-site-installs).)

### Assets & template lookup

- **The plugin/theme asset-precompile list is a boot-time snapshot.** A Sprockets-3 host app that appends
  its own `config.assets.paths` in an initializer running *after* the engine's will not have those files
  precompiled in production. Drive precompilation from `manifest.js` (as the maintained host apps do)
  rather than appending paths after boot.
- **A fully theme-scoped `render prefixes: [...]` is looked up in exactly those prefixes.** When the list
  is entirely theme-scoped (only `themes/<slug>/views` and/or `camaleon_cms/default_theme`), the
  controller/global prefixes are deliberately not merged — so a theme partial cannot resolve another
  site's per-site override or a plugin's views. A render that needs a controller-owned template must
  include a non-theme prefix in the list.

### Data-scope note (unreleased-tracking installs only)

- Rows written by unreleased master-tracking installs under the short-lived prefixed scopes
  (`'Widget::Main'`, `'Admin::User'`) are not migrated; released installs are unaffected.

---

## Rollback notes

- **User field groups (namespaced `user_model`):** after `demodulize_user_field_groups` runs, rolling
  back to 2.9.2 hides those groups on the user edit page until you re-upgrade. The data is intact.
- **Sidebar widget assignments:** assignments created on 2.9.3 are stored with the compact
  `Widget::Assigned` discriminator. 2.9.2 reads only the full `CamaleonCms::Widget::Assigned` name, so
  rolling back to 2.9.2 hides every assignment created on 2.9.3 (they reappear on re-upgrade — the upgrade
  direction reads both spellings), and raw SQL filtering on the old value misses rows written on 2.9.3.

---

## Recommended rollout

1. Upgrade to `2.9.3` and `bundle update camaleon_cms`.
2. For scripted **remote** installs, set `CAMALEON_SETUP_TOKEN` before running the installer.
3. On existing installs, rotate any administrator still using the historical default password.
4. Re-request any administrator password-reset link that was outstanding at upgrade time.
5. Clear `public/tmp/` once (see above).
6. Run the two read-only audit scans (`scan_content`, `scan_uploads`) and review anything they list.
7. Run only the repair tasks whose row in the [at-a-glance table](#at-a-glance--what-applies-to-you)
   applies to your install.
8. In production, confirm `Rails.cache` uses a shared store.
9. If you maintain a theme or plugin, review [Notes for theme & plugin developers](#notes-for-theme--plugin-developers).
