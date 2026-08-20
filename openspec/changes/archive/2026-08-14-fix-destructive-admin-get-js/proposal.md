# Stop JS-coupled destructive admin actions from riding GET (M6 follow-up 2 of 2)

## Why

Rails' CSRF protection exempts GET and HEAD entirely, so a state-changing endpoint on a GET route
is forgeable with an `<img>` tag or a link the victim clicks. Follow-up 1 (#1264) converted the
plain-link set; this change completes audit finding M6 with the three routes whose callers are
JS-coupled: the nav-menu item delete (a bare `$.get` that destroys a menu item), the legacy
appearances widgets delete routes (delete-shaped endpoints still admitting GET), and media `crop`
(`via: :all` — every verb, GET and HEAD included, reaching an action that writes a cropped upload
and can rewrite a user's avatar via `saved_avatar`).

### Triage verdict: legit

`config/routes/admin.rb` carried `item_delete` as `get`, `widgets`/`widget_delete` as
`via: %i[get delete]`/`%i[get patch]`, and `crop` as `via: :all`. Reproduced in
`spec/requests/security/admin_destructive_get_verbs_spec.rb`: on the old routes a GET destroys the
menu item and rewrites the stored avatar (red before the fix, spec-first).

## What Changes

- nav_menus `item_delete/:id` → **DELETE**. The click handler in `nav_menu.js` issues
  `$.ajax type: 'DELETE'` instead of `$.get` — jquery_ujs' prefilter attaches the X-CSRF-Token
  header to any non-GET ajax. The ERB link is unchanged (`url_for` generation is verb-agnostic).
- appearances `widgets` → **DELETE**-only and `widget_delete` → **PATCH**-only (GET dropped from
  both). These routes have pointed at a controller deleted in 2015 (`34159392`) — nothing executes
  today, on any verb — but the route table still declared a GET-reachable delete surface. The
  non-GET verbs stay routable so the paths and helpers remain for any external binding; there are
  no callers to fix (verified in core and every surveyed ecosystem clone).
- media `crop` → **POST**-only. The admin cropper never calls this route (it POSTs
  `media_action: 'crop_url'` to `media#actions`); no core or surveyed-ecosystem caller exists.
- Each conversion removes its action from the routing audit's `allowed_get_actions` allowlist
  (`spec/routing/admin/state_changing_verb_audit_spec.rb`), leaving only the deliberate
  logout/back_to_parent confirmation pair — the audit spec then enforces every conversion forever.

## Ecosystem consumers (surveyed clones + `docs/ai/ecosystem.md`)

Per the `ecosystem-plugin-bindings` requirement — grepped every sibling audit clone (cama_*,
camaleon*, florsan, camaleon_website, admin-ajax) for the three paths, their route-helper forms,
and an `AppearancesController` definition a plugin might supply for the dead widgets routes:

- **`item_delete` / `delete_menu_item`** — no consumer outside core (the core JS click handler is
  the only caller, converted in this change).
- **`widgets` / `widget_delete` / `widgets_save` / `AppearancesController`** — no consumer, and no
  plugin defines the missing controller; the surface is dead everywhere.
- **`media/crop`** — no consumer. The only crop-adjacent ecosystem file is `camaleon_website`'s
  vendored `croppic.js`, which is never instantiated — and even it would POST.

## Notes for upgraders

- External scripts that drove these paths over GET stop working: the nav-menu item delete requires
  DELETE and `crop` requires POST — each with a CSRF token. (The legacy widgets routes point at a
  controller removed in 2015, so no working GET caller exists to migrate.) The admin UI's own
  callers are updated.

## Out of scope

- The unscoped `CamaleonCms::User.find(params[:saved_avatar])` inside `crop` (any user's avatar,
  not just the caller's) — a separate audit Low adjacent to this route; the verb conversion
  neither fixes nor worsens it.
- Removing the dead legacy widgets routes outright (and `widgets_save`/`render_form` with them) —
  a route-contract cleanup, not a security fix; this change only closes their CSRF-exempt surface.
- `media#upload`'s CSRF-skip (audit M7).
