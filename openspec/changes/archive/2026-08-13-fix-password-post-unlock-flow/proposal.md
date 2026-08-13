# Fix the password-post unlock flow (GET, cleartext, timing-unsafe)

## Why

The password-post prompt was a method-less `<form>` (submits over GET) with a `type='text'` input, and
the gate compared `params[:post_password] == post.visibility_value`. The password therefore appeared
in the address bar, browser history, server/proxy logs and `Referer` headers, was shown on screen
while typed, and was compared without constant-time guarantees. Audit finding M2. Frontend post routes
are GET-only, so the unlock must move to its own POST endpoint (approach A, decided).

### Triage verdict: legit

Reproduced in `spec/requests/security/password_post_unlock_flow_spec.rb`: on unfixed code the GET
parameter unlocks the body, and the form has no method/POST action and a text-type input
(stash-verified failures).

## What Changes

- New plugin front endpoint `POST /plugins/visibility_post/unlock/:post_id`
  (`Plugins::VisibilityPost::FrontController#unlock`): finds the post through
  `current_site.the_posts` (site-scoped, frontend-visible), 404s unless it is password-protected,
  compares with `ActiveSupport::SecurityUtils.secure_compare`, marks the post id unlocked in the
  session, and redirects back to the post. A wrong password sets a flash flag and redirects back; the
  form then shows a translatable error.
- `_password_form` becomes a real POST form: `method='post'` to the unlock path, CSRF
  `authenticity_token`, `type='password'` input (and the malformed `<form>` closing tag is fixed).
- The shared lock predicate now reads the session marker; the query-string parameter no longer
  unlocks anything. The session stores only post ids — never the password.

## Notes for upgraders

- Bookmarked links carrying `?post_password=` no longer unlock a post; visitors enter the password in
  the (now POST) prompt instead. Themes overriding `plugin_visibility_post_the_content` or the form
  markup should adopt the new form.

## Out of scope

- Brute-force throttling of the unlock endpoint. The H1 login throttle's cache-counter pattern fits if
  wanted later; a shared-secret post password is a lower-value target than an account credential, and
  the endpoint is CSRF-protected POST with constant-time comparison.
- Hashing `visibility_value` at rest (it is a shared content secret, not an account credential; hashing
  it would break the admin's ability to see/share the configured password).
