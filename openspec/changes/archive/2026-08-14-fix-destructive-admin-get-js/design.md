# Design

## D1. Verb conversion, one commit per route, allowlist shrink rides each commit

As in follow-up 1, these endpoints have no read half, so the route verb changes and GET simply
stops matching (falls to the admin catch-all; decisively, no state change). Per the maintainer's
instruction each route lands in its own commit, and each commit also removes its action from
`allowed_get_actions` in `spec/routing/admin/state_changing_verb_audit_spec.rb` — the walk-the-
route-table audit then enforces that conversion from the same commit forward, and the allowlist
ends at the deliberate logout/back_to_parent confirmation pair.

## D2. The legacy widgets routes are narrowed, not removed

`widgets`, `widget_delete` (and `widgets_save`, `render_form`) target
`camaleon_cms/admin/appearances` — a controller deleted in 2015 (`34159392`, "comments module
rebuilt") when the widgets UI moved to `widgets/{main,sidebar,assign}`. Nothing dispatches today
on any verb; even `recognize_path` refuses the missing constant. Deleting the routes would be the
deeper cleanup but is a route-contract change (named helpers vanish) beyond a security fix's
scope, so this change only drops GET: the CSRF-exempt surface closes, the helpers stay routable.
Because nothing can execute, the reproduction pins the fact at the route table itself — the same
layer the audit spec enforces — not via requests or `recognize_path` (both raise on the missing
controller regardless of verb).

## D3. nav_menu.js sends a token-bearing DELETE; the ERB link is untouched

The delete link's click handler already owns the request (`$.get`), so it converts in place to
`$.ajax({type: 'DELETE'})` — jquery_ujs (in the admin manifest) registers an ajax prefilter that
attaches X-CSRF-Token to every same-origin request (it gates on crossDomain, not the verb), so the
DELETE carries the token. No `data-method` on the link: the handler would still fire and a
second ujs-driven request would double-delete. `url_for` route generation is verb-agnostic, so the
`_menu_items.html.erb` link keeps generating the same href for the now-DELETE route.

## D4. crop becomes POST-only

The admin cropper never calls `/admin/media/crop` — it POSTs `media_action: 'crop_url'` to
`media#actions` — and the ecosystem scan found no external caller (camaleon_website's vendored
`croppic.js` is never instantiated, and would POST). POST matches the one plausible legitimate
shape (a write carrying crop coordinates). The pre-existing `crop_spec.rb` suite converts its
requests to POST; the unscoped `User.find(params[:saved_avatar])` inside the action is a separate
audit Low, deliberately untouched here.

## D5. Testing: state-unchanged assertions, and meta reads through a fresh record

The reproduction examples assert state-unchanged (menu item still exists, stored avatar
unchanged), not response shape — converted-GET paths render the catch-all's not-found, never a
RoutingError. Two traps surfaced writing them: `recognize_path` cannot pin the widgets routes
(D2), and `set_meta`/`get_meta` memoize per instance (`cama_fetch_cache`), which `reload` does not
clear — an instance-cached read masked the crop write and turned the GET example into a false
green, so the spec reads the avatar through a freshly-found record. The `:js` feature spec
(`spec/features/admin/menus_spec.rb`) drives the converted nav-menu delete end-to-end through the
real click handler.
