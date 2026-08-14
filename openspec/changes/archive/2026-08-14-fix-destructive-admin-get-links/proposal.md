# Stop destructive admin actions from riding GET links (M6 follow-up 1 of 2)

## Why

Rails' CSRF protection exempts GET and HEAD entirely, so a state-changing endpoint on a GET route is
forgeable with nothing but an `<img>` tag or a link the victim clicks: trash or restore any in-site
post, flip a comment's moderation state, deactivate or upgrade a plugin (running its hooks), send
mail through the site's SMTP, end a session — or, highest-value, force an admin's session to switch
to another user (`impersonate`). Audit finding M6; #1252 fixed the worst vector (the custom-fields
list write) and this is the first of its two planned follow-ups: the endpoints whose callers are
plain `link_to` GETs (plus two adjacent state-changing GETs the original list omitted, `test_email`
and `logout`). The JS-coupled routes (nav-menu item delete, widget deletes, media crop) are
follow-up 2.

### Triage verdict: legit

`config/routes/admin.rb` carried all seven as `get` routes; every caller was a plain link or a
`$.get`. Reproduced in `spec/requests/security/admin_destructive_get_verbs_spec.rb` (stash-verified:
on the old routes, the GETs perform the state changes and the logout examples fail).

## What Changes

- Routes: posts `trash`/`restore` → PATCH, comments `toggle_status` → PATCH, plugins `toggle` →
  PATCH and `upgrade` → POST, users `impersonate` → POST, settings `test_email` → POST. A GET to
  those paths no longer matches an admin route and performs nothing.
- `logout` accepts GET and POST, but only the POST ends the session (keyed on `request.post?` —
  Rails exempts HEAD from CSRF exactly like GET). The GET renders a confirmation page instead of
  404ing, because frontend themes across the ecosystem link this path; the impersonation flow keeps
  its redirect to the `back_to_parent` re-auth, and a de-authenticated request still runs
  `cama_logout_user`'s cleanup on any verb (the H6 stale-stash property, pinned by the existing
  impersonation specs).
- Callers: admin links gain `method:` (jquery_ujs is in the admin manifest and builds the
  CSRF-token form); the test-email dialog's `$.get` becomes `$.post` (the ujs prefilter attaches
  the token to non-GET ajax); every logout caller becomes `button_to` — the admin header, the
  `back_to_parent` full-logout, and the two bundled theme layouts, where no rails-ujs exists and a
  `data-method` link would silently degrade back to GET.

## Ecosystem consumers (surveyed clones + `docs/ai/ecosystem.md`)

Per the `ecosystem-plugin-bindings` requirement, the consumers of the converted paths and their
dispositions:

- **logout** — the only endpoint with runtime consumers, all GET links, which is why it degrades
  gracefully instead of breaking: `cama-ecommerce-theme` and `camaleon-cms-efashion`
  (`cama_admin_logout_url(return_to: site_current_url)` — `return_to` is carried through the
  confirmation into the POST, then vetted by the safe-redirect check as before),
  `camaleon-cms-shoppy`, the bundled `default`/`new` themes (updated to `button_to` in this change),
  and the host apps `florsan` (theme link) and `camaleon_website` (three theme links plus its store
  plugin's server-side `redirect_to cama_admin_logout_path`, which now lands on the confirmation —
  one extra click). `camaleon-spree` replaces the logout path helpers wholesale and is unaffected.
- **plugins `toggle`** — referenced only by `camaleon_image_optimizer`'s and
  `camaleon_sitemap_customizer`'s own localhost integration tests; no runtime consumer. Those tests
  will need a verb update if ever run against a current core.
- **trash/restore, toggle_status, impersonate, test_email, upgrade** — no consumer in any surveyed
  repository; converted on the engine's merits.

## Notes for upgraders

- External links to the converted admin paths stop working over GET (the admin UI's own links are
  updated). `GET /admin/logout` keeps working for themes and bookmarks — it now shows a one-click
  confirmation instead of logging out directly, preserving `return_to`.

## Out of scope

- Follow-up 2 (JS-coupled routes): nav_menus `item_delete`, appearances widget deletes reachable
  over GET, and narrowing media `crop` from `via: :all`.
- `media#upload`'s CSRF-skip (audit M7) and the drafts `field_options` permit (M8 remainder).
