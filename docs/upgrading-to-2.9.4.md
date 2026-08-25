# Upgrading to 2.9.4

Version `2.9.4` is a small security and maintenance release. It picks up a contact-form security
fix from the bundled `cama_contact_form` plugin, scopes the bundled `front_cache` plugin's cache
invalidation, adds a save-time shortcode-permission gate in core, and ships a handful of bug and
performance fixes.

As always under this project's *reject on save, never rewrite* model, **nothing you already stored
is modified by upgrading**. Each change is described in full in [CHANGELOG.md](../CHANGELOG.md),
where **breaking changes** are flagged per entry; this guide is the upgrader runbook — what to do,
what you may observe, and what theme/plugin developers should know.

## At a glance — what applies to you

| If your install… | Do this |
| --- | --- |
| **Any install** | `bundle update camaleon_cms` — see [below](#pick-up-the-dependency-and-security-fixes) |
| Uses the **contact form** | Same bundle update; it closes the auto-reply recipient issue (CF-1) |
| Has non-admin roles that author **shortcodes** | Grant them the new **content_shortcodes** permission |
| Runs the bundled **front_cache** plugin on **FileStore** | Optional: clear the cache once to reclaim pre-upgrade `pages/…` files |

If you maintain a theme or plugin, also review
[Notes for theme & plugin developers](#notes-for-theme--plugin-developers).

---

## Pick up the dependency and security fixes

The one action for every install:

```bash
bundle update camaleon_cms
```

This raises the `cama_contact_form` floor to `~> 0.1.13` and picks up several transitive patch
updates. Nothing to add to your `Gemfile`. `cama_contact_form` `0.1.13` fixes:

- **Contact-form auto-reply recipient validation (CF-1).** The optional confirmation e-mail was
  sent to whatever address the visitor typed into the field named by the `to_answer` setting — an
  unauthenticated, fully attacker-controlled recipient — turning a site into an email relay from
  its own From address. The recipient must now be a single well-formed address, so one submission
  can neither header-inject a `Bcc` nor fan out to a list; a refused auto-reply is logged. The owner
  notification is unaffected.
  [cama_contact_form#76](https://github.com/owen2345/cama_contact_form/pull/76).
- **Markup gate routed through `CamaleonCms::UnsafeMarkup`**, closing an entity-encoded-markup
  bypass through a kept attribute (e.g. a `data-html` tooltip sink).
  [cama_contact_form#75](https://github.com/owen2345/cama_contact_form/pull/75).
- **The plugin's `forms` shortcode is declared to the shortcode registry**, so it is covered by the
  new `content_shortcodes` gate below.
  [cama_contact_form#69](https://github.com/owen2345/cama_contact_form/pull/69).

---

## front_cache page caching

The bundled `front_cache` plugin previously ran `Rails.cache.clear` on every POST/PATCH, wiping
every cache-based counter in the shared store (including the per-IP login brute-force counter).
Pages are now cached per site under versioned keys — one entry per URL, a one-week TTL, on any
store — and invalidation bumps a version the plugin owns rather than clearing the whole store.

- **Breaking change:** the *Invalidate the cache instead of deleting it* checkbox is removed; a
  stored `invalidate_only` value is ignored. **PUT and DELETE now invalidate** the page cache like
  POST/PATCH; **draft autosaves (`posts/drafts`) no longer invalidate it** (a draft is not published
  content); and the admin **Clean cache** action now also physically purges the site's stored pages.
- **Operator note (FileStore only).** Pre-upgrade `pages/…` entries are keyed under the old scheme
  and are simply superseded — no action is required. To reclaim the old files immediately, clear the
  cache once during your upgrade window:

  ```bash
  RAILS_ENV=production bundle exec rails runner 'Rails.cache.clear'
  ```

- **Theme/plugin developers:** third-party `Rails.cache` entries are no longer implicitly wiped on
  every POST — a fragment cached without its own invalidation now lives until its own TTL.

---

## Shortcodes in authored content are gated

Shortcodes in authored content are now gated behind a default-off `content_shortcodes` role
permission. A save carrying a **registered** shortcode is refused (never sanitized) for a non-admin
lacking the permission, across post content, custom-field values, taxonomy content and widget
descriptions. Admins, stored content and rendering are unaffected.

- **Breaking change:** a non-administrator role without `content_shortcodes` can no longer publish
  shortcode-bearing content on those surfaces. Grant the permission at **Settings → User Roles →
  *Allow shortcodes in content*** to roles that author shortcodes.
- **Theme/plugin developers:** a shortcode is gated only if its name is declared to the boot
  registry. Core declares its own; a theme or plugin registering shortcodes must declare their names
  through the DSL from its own boot (request-independently), e.g.
  `CamaleonCms::ShortcodeRegistry.register('redirect', 'my_slider')`. Rendering is untouched — the
  render-time `shortcode_add` handler is unchanged.

---

## Notes for theme & plugin developers

Beyond the front_cache and shortcode notes above:

### Frontend listings preload their associations

Frontend post listings (`the_posts`/`the_contents`) now `preload` post `metas`, `categories`,
`post_tags` and post-type `metas` instead of joining `metas`. A view that filters or sorts `@posts`
on a `metas` column must chain `.joins(:metas)` / `.eager_load(:metas)` itself, and a column-narrowed
`select` on `the_posts` must keep `taxonomy_id` (or use `pluck`). Single-post lookups stay lean.

### Test harnesses using the engine's factories

The engine no longer force-requires `factory_bot_rails` nor appends its `spec/factories` to the
application's factory paths. A camaleon-backed test harness that used the engine's factories from a
path/git checkout must now set `FactoryBot.definition_file_paths` itself (see
[docs/ai/testing.md](ai/testing.md)). Released-gem installs never received the factories (`spec/` is
not packaged), so they are unaffected.

---

## Recommended rollout

1. `bundle update camaleon_cms`.
2. Grant `content_shortcodes` to any non-admin role that authors shortcodes.
3. On FileStore, optionally clear the cache once to reclaim pre-upgrade `front_cache` files.
4. If you maintain a theme or plugin, review
   [Notes for theme & plugin developers](#notes-for-theme--plugin-developers).
