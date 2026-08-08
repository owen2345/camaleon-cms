# Design: restore-runtime-compat-surfaces

## Scope decisions from the ecosystem survey

The survey (`docs/ai/ecosystem.md`) trimmed the batch the audit first proposed:

- **Dropped the `@cama_current_user` ivar-read (M16).** Its justification was external SSO plugins
  assigning the ivar; the actual SSO plugin (`camaleon_oauth`) signs in through Doorkeeper and
  `login_user_with_password`, and no surveyed repo writes the ivar. Only the nil-memoization half is
  kept.
- **Dropped restoring `include Admin::ApplicationHelper` on `AdminController`.** No hook or controller
  calls `cf_add_model`, `do_shortcode` or the admin view helpers from controller context, so M18/M19/M23
  work without it.
- **M22b is `sanitize`, not escape.** `camaleon-ecommerce` ships an Orders-menu title carrying
  `<span><small class='label'>`; escaping shows literal markup. Neither `escaped-title-composition` nor
  `generated-markup-escaping` governs admin menu titles, so there is no hard requirement to violate.

## M16 — memoize the nil, keep the external set

`cama_current_user` guarded on a truthy `CurrentRequest.user`, so a signed-out request re-ran the API
lookup and an auth-token `find_by` every call. A `user_resolved` flag on `CurrentRequest` memoizes the
outcome; the guard becomes `CurrentRequest.user || CurrentRequest.user_resolved`, so an externally-set
user (the spec helpers, admin controller) is still returned, and logout marks resolved so nothing
re-resolves against a deleted cookie.

## M22 — quote-aware datas, SafeBuffer-aware titles

`parse_datas` now matches `'…'` or `"…"` so a value may contain the other quote. For titles, core builds
SafeBuffers via `safe_join`/`content_tag` and those pass through `cama_admin_menu_title` untouched; a
plain-String plugin title is sanitized to `span/small/i/b/strong/em` + `class`. Master already escaped
titles, so this is not a security regression — it is strictly safer than 2.9.2 (which rendered them raw)
and less breaking than master.

## M19 — object identity is the contract

The `@_admin_menus.delete('comments')` idiom needs the ivar to alias the same hash `admin_menu_draw`
reads. `admin_menu_add_menu`/`append`/`prepend` already mutate in place; only
`admin_menu_insert_menu_before`/`after` reassigned `CurrentRequest.admin_menu_items` to a fresh hash.
Both copies (controller concern and view helper) now `.replace` in place, and `admin_init_actions`
aliases `@_admin_menus` onto the store, so a reference taken at init stays valid through menu building.

## M20 — read fallback only, write side unchanged

Core already writes both `CurrentRequest.<attr>` and the legacy `@cama_visited_*` ivar (with a
deprecation warning) — the break was read-only. `camaleon_frontend_visited_state`,
`camaleon_frontend_object` and the SEO `frontend_user` read now fall back to the legacy ivar (read via
`instance_variable_get`) when `CurrentRequest` is unset. The two specs #1183 added to assert the removed
fallback are inverted to assert it, matching `docs/ai/reference.md`'s claim that the ivars remain
assigned for ecosystem compatibility.

## Testing

One repro per finding, red before the fix. Auth (230), admin (143) and frontend (45) request/helper
specs plus the full suite (1196) confirm no cross-cutting regression.
