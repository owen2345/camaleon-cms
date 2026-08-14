# Design

## D1. Verb conversion, not verb-guarding

#1252 guarded a mixed read/write action in place (`request.post?` inside the action) because the
route legitimately serves a GET render too. These seven endpoints have no read half — every one is
purely a state change — so the route verb itself changes and the GET simply stops matching. A GET
to the old paths falls through to the frontend catch-all and renders not-found, which is the
fail-closed outcome; the reproduction spec pins the decisive property (no state change) rather than
the response shape.

## D2. Logout gets a confirmation, not a 404

Logout is the one converted path with a public link surface: the bundled themes (and, per
`docs/ai/ecosystem.md`, an unknowable number of external ones) link `cama_admin_logout_path` from
frontend layouts. Breaking those links outright would push every theme into a lockstep upgrade, so
the GET stays routable and renders a confirmation page whose single button POSTs the actual logout
(`?full=1` is carried through for the impersonation case). Signed-in flows in our own UI POST
directly — no extra click. Two invariants carry over untouched: an impersonating session's Logout
still redirects to the `back_to_parent` re-auth, and a request that is no longer authenticated
still reaches `cama_logout_user`'s cleanup on any verb, because a forged GET against a signed-out
session ends nothing while a stale impersonation stash (H6) must still be cleared.

## D3. UJS where it exists, button_to where it does not

The admin manifest requires `jquery_ujs`, so admin links use `link_to method:` (data-method), the
established idiom in these views (comment delete, custom-field delete), and the test-email dialog
swaps its explicit `$.get` for `$.post` (the ujs prefilter adds the CSRF header to non-GET ajax —
already documented at `_post.js:241`). The frontend loads no rails-ujs, so the theme-layout logout
links become `button_to` forms: a `data-method` link without ujs degrades silently back to a plain
GET, which is exactly the bug class this change removes.

## D4. Testing

`spec/requests/security/admin_destructive_get_verbs_spec.rb`: for each converted endpoint, a GET
performs no state change (post not trashed, comment stays pending, plugin stays active, session not
switched, no mail delivered) and the proper verb performs it; logout keeps the session on GET,
shows the confirmation, and ends the session only on POST. Stash-verified red against the old
routes. The pre-existing impersonation, logout, open-redirect, plugins, settings and
target-resolution suites are updated to the new verbs — their old GET form is exactly the removed
behavior — and the H6 stale-stash example caught (and now pins) the de-authenticated-cleanup
regression during development.
