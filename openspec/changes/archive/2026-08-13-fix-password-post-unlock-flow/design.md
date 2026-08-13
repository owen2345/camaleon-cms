# Design

## D1. A plugin front controller, not a core route

The unlock belongs to visibility_post, so it ships inside the plugin: `config/routes_front.txt` (the
existing `PluginRoutes.load('front')` mechanism draws it under `/plugins/visibility_post/`, numeric
`post_id` constraint) and `front_controller.rb` (`CamaleonCms::Apps::PluginsFrontController` base, so
the endpoint is dead when the plugin is inactive). Core routes stay untouched.

## D2. Session marker, not a session password

`session['cama_visibility_unlocked_posts']` holds unlocked post ids (key shared with the helper via
`SESSION_UNLOCKED_KEY`). Storing ids instead of the password means the session never carries the
secret, and the M1 lock predicate needed only its unlock source swapped. Accepted trade (WordPress
cookie-model parity): changing a post's password does not re-lock sessions that already unlocked that
id — the marker is per-session and expires with it; re-verifying the stored password each request
would require keeping the password (not just the id) in the session, which is worse.

## D3. Redirect-back derivation

The controller redirects to `post.decorate.the_url(as_path: true)` — derived server-side from the
post record, never from a request parameter — so the endpoint cannot be used as an open redirect.

## D4. Error feedback

A wrong password sets `flash[:cama_visibility_post_error] = true` (a flag, not text) and redirects
back; `_password_form` renders the translatable message (`ct('wrong_password', …)`). Success and
failure both answer with a redirect to the same URL, so the response shape leaks nothing beyond the
flash.

## D5. front_cache interaction

The form embeds a live `form_authenticity_token`. Pages carrying the password prompt should not be
added to front_cache's cached paths (the same constraint as any CSRF-protected form; front_cache's
token-replacement hook covers only its known placeholders).

## D6. Testing

Request spec (`password_post_unlock_flow_spec.rb`): GET parameter no longer unlocks; the prompt is a
POST form with a password-type input and CSRF token; wrong password redirects back locked with the
error; right password unlocks the session (subsequent plain GET shows the body); a non-password post
404s. All fail on unfixed code (stash-verified). The existing feature spec's "password post with
password" example is rewritten to the real browser flow (fill the form, submit, body appears) — its
old form (GET parameter in `visit`) is exactly the removed behavior.
