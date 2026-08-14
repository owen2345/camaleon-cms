# Change Log

## Unreleased

- **Security fix:** Low-severity hardening bundle. The captcha challenge is now drawn from a CSPRNG
  instead of `Kernel#rand`; the public `save_comment` endpoint no longer 500s on a bad post id or a
  missing payload; the media crop avatar target is resolved within the current site (no cross-tenant
  write or existence oracle); and the `front_cache` plugin keys its page cache on a lossless digest
  instead of a lossy `parameterize` (so distinct URLs can no longer collide onto one cached page).
  [#1267](https://github.com/owen2345/camaleon-cms/pull/1267).
  - **Notes for upgraders:** existing `front_cache` entries are keyed under the old scheme and simply
    regenerate once after upgrade — no action needed.

- **Security fix:** Four medium-severity admin hardenings. `media#upload` no longer skips CSRF
  verification (the multipart uploader now sends the token); draft custom-field options are confined
  to the post type's registered slugs like the main post save; the nav-menu reorder resolves its
  destination menu through the current site, so an item cannot be moved into another site's menu; and
  the email-confirmation token is consumed on use, like the password-reset token. Review follow-ups
  in the same PR harden the shared custom-field save path: `set_field_values` derives each value's
  `custom_field_id` from the field slug (a forged id can no longer point a value at a different field
  type to slip past the scan-and-reject gate), and the field-options permit ignores a non-hash
  payload instead of raising.
  [#1266](https://github.com/owen2345/camaleon-cms/pull/1266).
  - **Notes for upgraders:** external scripts that POSTed to `/admin/media/upload` without a CSRF
    token stop working — send the `authenticity_token` field (or `X-CSRF-Token` header). First-party
    uploaders are updated.
  - A submitted custom-field `id` that does not match its slug is ignored — the id now always comes
    from the field the slug names.

- **Security fix:** The remaining destructive admin endpoints no longer answer GET (completing the
  audit's M6): deleting a nav-menu item requires DELETE (the admin JS sends it with the CSRF token),
  the legacy `appearances/widgets` delete routes no longer admit GET, and `media/crop` — previously
  reachable over every verb — accepts only POST. A routing audit spec now enforces that no
  mutation-named admin route answers GET/HEAD outside the deliberate logout confirmation pair.
  [#1265](https://github.com/owen2345/camaleon-cms/pull/1265).
  - **Notes for upgraders:** external scripts driving the nav-menu item delete or `media/crop` over
    GET stop working — send DELETE or POST with a CSRF token instead. (The legacy
    `appearances/widgets` routes point at a controller removed in 2015, so no working GET caller
    exists to migrate.) The admin UI's own callers are already updated.

- **Security fix:** Destructive admin actions no longer ride GET links, which Rails' CSRF protection
  exempts entirely: trashing/restoring posts, flipping comment moderation, toggling or upgrading
  plugins, impersonating a user, sending a test email, importing a theme's sample data, and logging
  out now act only over PATCH/POST, carried by the admin UI's own links and forms.
  [#1264](https://github.com/owen2345/camaleon-cms/pull/1264).
  - **Notes for upgraders:** external links to the converted admin paths stop working over GET.
    `GET /admin/logout` keeps working — it now shows a one-click confirmation page instead of
    logging out directly, so themes that link it (including older ones) keep functioning.

- **Security fix:** Post content from untrusted authors is now rejected on save when it contains
  disallowed HTML, instead of being silently sanitized. Under the project's security model untrusted
  input is refused, never rewritten: the save fails with a validation error naming the remedy, and
  stored content always equals authored content. Trust is unchanged — admins and roles holding
  `post_content_unfiltered_html` for the post type save anything, and `unfiltered_content!` still
  opts server-side pipelines out. [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).
  - **Notes for upgraders:** a save that previously went through with markup stripped now fails with
    an error until the author removes the markup (or is granted the permission). Stored content is
    not rewritten; `rake camaleon_cms:security:scan_content` lists what would be refused today.
    `data-*`/`aria-*` attributes are now accepted (previously silently stripped) — but a value that
    decodes to markup is still refused, so a `data-html`-style sink cannot be fed through one. Content
    beyond a generous size bound (a few MB) is refused with a distinct "too large" error. The
    theme-DSL helper `the_content` no longer sanitizes at render either — it emits stored content
    verbatim, like the templates always did.

- **Security fix:** Unlocking a password-protected post now happens over POST with a session-side
  unlock and a constant-time comparison. The prompt used to submit over GET with a text-type input —
  putting the password on screen and into URLs, browser history, logs and `Referer` headers — and the
  gate compared it with `==`. The form now posts to a dedicated plugin endpoint (CSRF-protected,
  `type='password'`) and the query-string parameter no longer unlocks anything.
  [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).
  - **Notes for upgraders:** bookmarked `?post_password=` links no longer unlock a post — visitors
    enter the password in the prompt instead. Themes that override the visibility_post password form
    should adopt the POST form markup.

- **Security fix:** Password-protected posts no longer leak their body through excerpts. The
  visibility_post plugin gated only the post content, while `the_excerpt` — shown by listing pages,
  search results and every RSS feed — was still derived from the body and visible to anyone. A locked
  post's excerpt is now a neutral "This content is password protected." notice (translatable); titles
  stay visible as before. Password-protected posts are also excluded from the front_cache page cache,
  so an unlocked render is never stored under the shared URL key and served to another visitor.
  [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).

- **Security fix:** The admin auth cookie is now `HttpOnly` and `Secure` (over SSL), and logging out
  rotates the server-side `auth_token`. Previously the cookie's bearer token was readable by JavaScript
  and sent in the clear, and a cookie copied before logout stayed valid. Because the token is per-user,
  logging out now ends the user's sessions on all devices.
  [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).
  - **Notes for upgraders:** logging out ends the user's sessions on all devices (the token is
    per-user); a full logout while impersonating leaves the impersonated user's own sessions alone.
    Changing your own password re-issues the cookie with the same `HttpOnly`/`Secure` hardening.

- **Security fix:** `field_attrs` custom-field values are now gated at save like editor values and
  rendered verbatim, closing a second stored-XSS path in the same partial as the `editor` fix. The
  gate scans the decoded members of any JSON shape (object or array), so markup hidden by the
  encoder's unicode escaping is refused like literal markup; nothing is sanitized or escaped away. A
  `field_attrs` field now also shows its stored value (it previously repeated the attribute name), and
  renders nothing for a non-object JSON value instead of erroring.
  [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).

- **Security fix:** Dangerous custom-field values are now rejected on save instead of being stored.
  Rich-text (`editor`) values were rendered with `raw` and URL-type values land in href/src, with no
  gate on what a non-admin could store — stored XSS. A value an untrusted author is not permitted to
  write (scripts, event handlers, embeds, `javascript:` URLs) is now refused with an error naming the
  field; nothing is ever sanitized or rewritten, so trusted authors' content stays byte-for-byte
  intact. Admins, and roles holding `post_content_unfiltered_html` for the post type, can store
  anything. [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).
  - **Notes for upgraders:** values stored before this gate are not rewritten — run
    `rake camaleon_cms:security:scan_content` to list stored posts and field values (editor,
    `field_attrs` and URL types) that would fail the gate today, and clean them up by hand. Writing a
    field value through `update_field_value` now applies the gate too, so a dangerous value is refused
    there instead of stored.

- **Security fix:** Passwords must now be at least 8 characters. The user model previously validated only
  presence and the 72-byte bcrypt maximum, so a one-character password was accepted on signup, change, or
  reset. The floor is length-only (NIST-aligned) and applies whenever a password is set; a profile update
  that leaves the password untouched is unaffected. [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).

- **Security fix:** The forgot-password endpoint no longer reveals whether an email is registered or
  lets itself be used to flood an inbox. It answered a matched email with a success notice and an
  unmatched one with a distinct "not found" error (a user-enumeration oracle), and re-sent a reset email
  on every request. It now returns one neutral message either way and sends at most one reset email per
  account per 5-minute window. [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).

- **Security fix:** Admin login no longer leaks whether a username exists through response timing. It
  verified the password with `@user&.authenticate`, so a missing username skipped bcrypt and answered
  faster than a wrong password for a real account (a username-enumeration oracle). Login now spends one
  bcrypt comparison on the missing-username branch too. [#1263](https://github.com/owen2345/camaleon-cms/pull/1263).

- **Security fix:** Two admin endpoints now enforce authorization. `AdminController#search` queried all
  posts with no status filter or permission check, so any admin-area user (e.g. a `client`) could
  enumerate every post title/slug in every status — plus post types, categories and tags they cannot
  manage; it now scopes each result kind to the caller's authorized post types (content further to
  own/`edit_other` posts; categories and tags by their own `manage_categories`/`manage_tags`
  abilities, covering nested categories). `Posts::DraftsController#index` rendered the post type as
  JSON with no check and now requires `:posts` authorization. [#1262](https://github.com/owen2345/camaleon-cms/pull/1262).

- **Security fix:** The admin post index no longer leaks another post type's posts through a taxonomy
  filter. It authorizes `:posts` on the post type in the URL, but `?taxonomy=category|post_tag` replaced
  the scope with the taxonomy owner's site-wide posts, so a user authorized on one post type could list
  another's posts (with `?s=all`, in every status) by passing a foreign category/tag id. The taxonomy
  filter is now resolved within the authorized post type (a foreign id 404s, so its name is not
  disclosed either) and intersected with that post type's posts. [#1262](https://github.com/owen2345/camaleon-cms/pull/1262).

- **Security fix:** Credential parameters are now filtered from the Rails logs. The engine set no
  `config.filter_parameters`, so the site-settings SMTP password and S3 keys (`options[email_pass]`,
  `options[filesystem_s3_access_key]`, `options[filesystem_s3_secret_key]`), user passwords, token
  parameters (e.g. the installer `setup_token`) and protected-post passwords
  (`post[visibility_value]`) were logged in cleartext on hosts without their own filter. The engine now
  appends the relevant filters (preserving any the host app already set). [#1262](https://github.com/owen2345/camaleon-cms/pull/1262).

- **Security fix:** Private uploads to S3 are now stored with an owner-only (`private`) ACL instead of
  `public-read`. Only the key prefix changed in private mode, so a private file was world-readable at a
  guessable `s3://bucket/private/<name>` URL, bypassing the `download_private_file` gate. Public uploads
  are unchanged; private serving is unaffected because it fetches through the authenticated S3 API.
  [#1262](https://github.com/owen2345/camaleon-cms/pull/1262).

  **Notes for upgraders:**
  - Objects already stored under the private prefix keep their `public-read` ACL until re-uploaded. Run
    `bin/rails camaleon_cms:repair_private_upload_acls` from the host app to sweep them back to
    owner-only; it covers every AWS-backed site, and `CAMA_S3_INNER_FOLDER=<folder>` handles setups
    whose uploader hook configures an `inner_folder` (their private root is `<inner_folder>/private/`,
    which a plain `private/`-prefix sweep would miss).

- **Fix:** The upload content scanner now accepts embedded raster images encoded as `data:image/*`
  URIs (for example an Inkscape/Figma SVG carrying `<image xlink:href="data:image/png;base64,…">`),
  which were previously rejected as false positives. Dangerous `data:` URIs (`data:text/html`,
  `data:image/svg+xml`, bare `data:,…`) and `javascript:`/`vbscript:` remain blocked, for both SVG
  and non-SVG uploads. [#1261](https://github.com/owen2345/camaleon-cms/pull/1261).

- **Security fix:** The uploaded-SVG scanner now rejects uppercase/mixed-case event-handler
  attributes (for example `ONCLICK`), matching the case-insensitive rule the non-SVG ruleset already
  applied. It also no longer raises on an SVG that declares a non-UTF-8 encoding — such a file is
  scanned normally instead of failing the upload with an error.
  [#1261](https://github.com/owen2345/camaleon-cms/pull/1261).

- **Security fix:** The uploaded-SVG scanner now catches blocked URI schemes (`javascript:`,
  `vbscript:`, `data:`) that hide a TAB/LF/CR gap inside the scheme name — e.g. `java&#9;script:` in an
  `xlink:href`, which a browser strips back to `javascript:` before executing. The SVG scanner is the
  only content gate for a served `.svg`, and its scheme checks lacked the gap tolerance the non-SVG
  ruleset already had, so such a file (auto-triggering with `<animate begin="0s">`) was accepted. Both
  scheme checks now share `ContentSecurity`'s gap-tolerant pattern and entity normalization.
  [#1261](https://github.com/owen2345/camaleon-cms/pull/1261).

- **Security fix:** `sort_by_field` no longer interpolates its sort-direction argument into the SQL
  `ORDER BY`. It is a public API (themes and plugins call `collection.sort_by_field(key, params[:order])`),
  so a user-controlled direction reached the `ORDER BY` clause: on Rails 6.1+ ActiveRecord blocks arbitrary
  injection there, but a hostile value still raised an unhandled 500, and a comma-separated direction could
  append attacker-chosen `ORDER BY` terms (a blind ordering oracle). The direction is now whitelisted to
  `ASC`/`DESC` (ascending by default) and the value column is ordered as a quoted identifier.
  [#1260](https://github.com/owen2345/camaleon-cms/pull/1260).

  **Notes for upgraders:**
  - `sort_by_field` now honors only the sort direction: the leading token of the `order` argument is
    matched against `asc`/`desc` case-insensitively — padded or modifier-bearing directions such as
    `'DESC NULLS LAST'` keep their direction, though the modifier itself is dropped — and anything
    else falls back to ascending. A caller that passed additional raw SQL through `order` must use
    `reorder` directly instead.

- **Fix:** `sort_by_field` and `filter_by_field` no longer append phantom unsaved records to the
  collection they are called on — class discovery now uses the relation's `klass` instead of `build`.
  [#1260](https://github.com/owen2345/camaleon-cms/pull/1260).

- **Change:** The `user_before_register` hook now fires during registration (it was previously dispatched
  as a silent no-op) — after the register captcha passes — and a handler can veto a signup by setting
  `r[:stop_process]`; the form shows a generic error unless the handler supplies its own. Follow-up to #1258.
  [#1259](https://github.com/owen2345/camaleon-cms/pull/1259).

- **Security fix:** Closed an open redirect in the admin session flows. `safe_redirect_url` treated any URL
  whose *parsed* host was blank as same-origin and returned it unchanged, but `return_to=///evil.com` (also
  `https:evil.com`, `javascript:...`) parses to a blank host yet sends a browser off-site — so
  `/admin/login?return_to=///evil.com` emitted it as `Location`. It now follows a host-blank destination
  only when it is a genuine same-origin path (rejecting scheme, protocol-relative/backslash and `%2f`/`%5c`
  forms), and follows a host-matching absolute URL only over an `http`/`https` scheme (rejecting a same-host
  `javascript:`/`data:` destination). The same host check now also guards `login_user`'s explicit
  `redirect_url` and the registration `user_registered` hook redirect (both set by hooks/downstream
  plugins), closing the matching post-login and post-registration open redirects.
  [#1258](https://github.com/owen2345/camaleon-cms/pull/1258).

  **Notes for upgraders:**
  - A plugin that intentionally redirects off-site after login or registration (SSO, payment providers) is
    now dropped to the safe default. Restore it by trusting the destination host: set the
    `redirect_allowed_hosts` site option (comma-separated) or append to it from the new `safe_redirect_hosts`
    hook (`r[:hosts] << 'checkout.stripe.com'`).
  - For a fully-dynamic off-site destination, an `after_login`/`user_registered` hook can set
    `r[:allow_external_redirect]` to vouch for its `redirect_to`/`redirect_url`. `http`/`https` only in both
    cases; a caller-supplied `return_to` is never opted in this way.

- **Fix:** The `user_before_register` hook now fires during account registration. It was dispatched with
  `hook_run` in a form that resolved to a no-op, so a plugin listening on it never ran; it now broadcasts
  like `user_before_login`. [#1258](https://github.com/owen2345/camaleon-cms/pull/1258).

- **Security fix:** Only an admin may control an admin account. Holding `:manage, :users` was a path to
  superadmin: a non-admin user manager could set `role: 'admin'` on a created or edited account (minting an
  admin) or strip an existing admin's role, and could also reset an admin's password to sign in as them or
  repoint their email to hijack a reset link. Granting or removing the `admin` role, and changing an
  existing admin's password, email, or username, now require being an admin — the server drops such changes
  and the user form hides and disables what the caller cannot use; non-admin accounts and a user's own are
  unaffected. A malformed nested `role` parameter is now ignored rather than raising (audit finding H10).
  [#1257](https://github.com/owen2345/camaleon-cms/pull/1257).

- **Security fix:** Admin login is now brute-force throttled per client IP. The "under attack" decision was
  a per-session counter, so an attacker who dropped their session cookie each request never triggered the
  captcha and could guess passwords without limit (H1); the bundled `attack` plugin keyed its own throttle
  and ban on the session id too and inserted a tracking row per request, an unbounded unauthenticated write
  (H2). Failed logins are now counted per IP in the cache: past the captcha threshold a captcha is required
  server-side (a fresh session no longer clears it), and past a higher `login_lockout_attempts` threshold
  the IP is refused with HTTP 429 for a cooldown; the `attack` plugin keys on `request.remote_ip` and stops
  inserting once over the limit. Upgrade notes: counters are per IP, so behind a shared IP a captcha may
  appear after enough failures from anyone on it (tune `max_try_attack` / `login_lockout_attempts`), and
  the per-IP counters use `Rails.cache` and are incremented atomically — use a shared store (Redis/memcached)
  in production so the throttle holds across workers. [#1256](https://github.com/owen2345/camaleon-cms/pull/1256).

- **Security fix:** The captcha is now a single, single-use challenge of bounded length. The
  unauthenticated `GET /captcha?len=` fed its length straight into challenge generation, so a huge value
  tied up the worker building an arbitrarily large challenge string for ImageMagick to draw (H4) and a
  value of `1` shrank the answer to one letter; meanwhile every issued answer was accumulated in the
  session and never cleared, and verification accepted any of them, so the captcha could be bypassed
  without solving it (H3). The length is now clamped, each image replaces the stored challenge, a solved
  captcha is consumed (a blank value never matches), and generation resolves to one shared module for both
  the controller and view entry points. Upgrade note: captchas are single-use now — render a fresh image
  per attempt instead of reusing one answer across submissions. Solving a captcha also no longer resets
  the login under-attack counter by itself; it clears only when the protected action succeeds, so
  downstream callers of `captcha_verify_if_under_attack` should call `cama_captcha_reset_attack(key)`
  after their own success (the bundled login flows already do).
  [#1255](https://github.com/owen2345/camaleon-cms/pull/1255).

- **Fix:** Saving a frontend comment no longer fails with a 500 when the client sends no `User-Agent`
  header; the header is now recorded nil-safely and without mutating the request's string in place.
  [#1255](https://github.com/owen2345/camaleon-cms/pull/1255).

- **Security fix:** Ending admin impersonation now requires the impersonating admin's password. Returning
  from an impersonated session replays the admin's auth cookie stashed in the session; previously the
  ordinary Logout link restored it for whoever held the session, so an admin who walked away
  mid-impersonation on a shared browser let the next occupant become admin. The Logout link now routes to
  a confirmation that verifies the admin's password before restoring (or lets the holder log out
  completely), closing the residual left by the H6 session-reset fix. Failed attempts feed the same
  brute-force throttle as the login form (captcha past the threshold), the confirmation does not
  disclose the admin's username, and a stash that can no longer be re-authenticated ends the session
  instead. [#1254](https://github.com/owen2345/camaleon-cms/pull/1254).

- **Security fix:** The session is now reset on a genuine sign-in and on logout. The admin
  "impersonate user" feature stashes the admin's auth cookie in the session so it can be restored on
  return; because the session was never rotated, that stash outlived the admin on a shared browser — a
  different user who signed in afterward inherited it and was handed the admin's cookie on logout,
  escalating to admin. `login_user` and `cama_logout_user` now call `reset_session`, and impersonation
  resets and re-stashes the token so switching and returning still work (audit finding H6). Downstream
  note: plugins that place data in the session during a `user_before_login`/`after_login` hook must move
  it elsewhere (a cookie, or after the redirect), because a sign-in now starts a fresh session.
  [#1253](https://github.com/owen2345/camaleon-cms/pull/1253).

- **Security fix:** The admin custom-fields "list" endpoint no longer writes a post's categories on a
  GET request. The read-named `GET /admin/settings/custom_fields/list` also called `update_categories`,
  and with the `categories` parameter omitted it deleted every one of the post's category relationships
  — reachable by CSRF, since a GET carries no forgery token and the auth cookie rides a top-level
  navigation. The category write now runs only on a CSRF-verified POST (Rails exempts HEAD as well as
  GET from CSRF verification), and the route accepts POST. The endpoint, which any signed-in user could
  reach, now also authorizes the caller against the resolved record — `:update` on the post (guarding
  both the field-value render and the category write) or `:create_post` on the post type — so it no
  longer discloses a post's custom-field values or rewrites its categories for users without those
  rights (audit finding M6). [#1252](https://github.com/owen2345/camaleon-cms/pull/1252).

- **Fix:** The admin `confirm_email` route now accepts PATCH. Its `via:` list carried `path` — not an
  HTTP verb, but a typo for `patch` (the verb its `forgot`/`register` siblings accept) — so a PATCH
  request fell through to the admin "invalid route" handler.
  [#1252](https://github.com/owen2345/camaleon-cms/pull/1252).

- **Security fix:** Foreign keys that carry a record's tenancy are no longer mass-assignable across
  sites. A post type's `parent_id` is its `site_id`, so a settings manager could re-home a post type
  (with its posts, categories, tags and field groups) onto another site by editing a hidden field; a
  category's or tag's `parent_id`, and a widget assignment's `sidebar_id`/`widget_id`, were reassignable
  the same way. `parent_id` is now dropped from the post-type and tag permits, validated against the
  current post type on categories, and the widget-assignment update no longer accepts
  `sidebar_id`/`widget_id` (audit findings H8 and H9).
  [#1251](https://github.com/owen2345/camaleon-cms/pull/1251).

- **Security fix:** The admin user-list and account-creation actions (`GET`/`POST /admin/users` and
  `GET /admin/users/new`) now require the `:manage, :users` capability even when the caller injects their
  own id as `?user_id=`. The `validate_role` self-exemption — meant for a user acting on their own record
  — was short-circuiting the capability check on these collection actions, which have no target user, so
  any authenticated user could read the full user table (including every email address) and create
  accounts, bypassing the `permit_create_account` registration setting (audit finding H7).
  [#1250](https://github.com/owen2345/camaleon-cms/pull/1250).

- **Security fix:** The breadcrumb, the HTML sitemap, and the bundled default theme's taxonomy links now
  HTML-escape the post/category URL they interpolate into an `href`. Because a slug persists byte-for-byte
  and Rails route generation does not percent-encode a single quote, a contributor could previously store
  a slug that closed the attribute and ran an event handler in a visitor's — or a same-origin
  administrator's — browser (audit finding H11). [#1249](https://github.com/owen2345/camaleon-cms/pull/1249).
  - **Notes for upgraders:** A slug containing HTML metacharacters that was already stored now renders as
    an inert, escaped link instead of executing. Ordinary slugs are unaffected — the output is
    byte-identical for URLs with no HTML-significant characters.

- **Fix:** Administrator password reset is working again. On Rails 7.1+ `has_secure_password` generates
  a `password_reset_token` method that shadowed Camaleon's same-named column, so the emailed reset link
  never matched the account lookup and every reset dead-ended on "URL incorrect". Reset links now
  resolve, expire, are single-use, confined to the account's own site, and reject a blank or
  malformed password. The session endpoints (login, registration, password reset) also no longer
  raise a 500 on a malformed `user` parameter.
  [#1248](https://github.com/owen2345/camaleon-cms/pull/1248).
  - **Notes for upgraders:** any password-reset links already outstanding at upgrade time are
    invalidated and must be re-requested (they were non-functional in practice). No schema change.

- **Security fix:** The installer no longer publishes a default administrator password and can no
  longer be run by an anonymous visitor on a fresh deploy (audit finding C1). New sites mint the
  `admin` account with a random password shown once on the installer confirmation page — now reachable
  only by the operator who just installed — and require a password change on first sign-in. The
  first-run installer is gated by a setup token, read from `CAMALEON_SETUP_TOKEN` or a generated
  `tmp/camaleon_setup_token` file. See [docs/installation.md](docs/installation.md) and
  [docs/upgrading-to-2.9.3.md](docs/upgrading-to-2.9.3.md).
  [#1246](https://github.com/owen2345/camaleon-cms/pull/1246).
  - **Notes for upgraders:**
    - **Scripted installs must now supply `CAMALEON_SETUP_TOKEN`.**
    - **Existing installs are not rewritten.** An administrator still using the historical default
      password should be rotated (admin profile screen or a `rails console` reset); the credential
      disclosure on the installer page is closed for all installs regardless.

- **Fix:** The captcha tag now honors a caller-supplied image style and string-keyed input
  attributes, and the admin "no categories/tags created" message shows a properly translated,
  localized label instead of the raw taxonomy slug; an internal shortcode-asset helper was realigned
  with its twin. Regression audit L14, L15, L17.
  [#1245](https://github.com/owen2345/camaleon-cms/pull/1245).
  - **Notes for upgraders:**
    - `ENV['CAMALEON_SKIP_URL_VALIDATION']` is an operator escape hatch that bypasses **all**
      upload-URL validation (scheme, host, SSRF/link-local, path traversal, HTML sanitization). It is
      for trusted, isolated environments only — leaving it set in production removes the SSRF and
      open-fetch protections around crop/crop_url. Regression audit L12.
    - The `SUSPICIOUS_PATTERNS` and unsafe-event-handler constants now live in
      `CamaleonCms::ContentSecurity`, not `CamaleonCms::UploaderHelper`. A plugin referencing the old
      path gets a `NameError`; update the constant path. Regression audit L4.

- **Fix:** A failed avatar crop now shows an error instead of silently blanking the saved avatar and
  returning an empty response; the theme generator and the custom-fields/site/cross-site repair rake
  tasks print their progress to the terminal (they logged only to a file before). Review follow-ups
  on the same branch (no behavior change): the tasks' terminal reporting moved into a shared
  `CamaleonCms::TaskReporter` helper and the theme generator lost a dead branch. Regression audit
  L3, L16, L11, L18. [#1244](https://github.com/owen2345/camaleon-cms/pull/1244).
  - **Notes for upgraders:** Post content edited during the 2.9.1–2.9.2 sanitize-on-save era stored
    HTML-escaped entities and may render visibly double-encoded once (e.g. `&amp;` shown literally)
    under the current escape-at-render behavior. There is no repair task — a blanket re-encode
    cannot tell a legitimately-authored `&amp;` from a sanitize-era artifact — but each affected
    field self-heals the next time it is edited and saved. Regression audit L7.

- **Security fix:** SVG uploads and `/media/` SVG responses are now matched by extension
  case-insensitively, so an uppercase-extension SVG (`image.SVG`) is scanned by the SVG parser and
  served with the `nosniff` / `script-src 'none'` headers like a lowercase one; the media security
  header keys are also emitted lowercase for Rack 3. Review follow-ups on the same branch: the
  SVG-to-JPG thumb/crop rename is case-insensitive too, so an uppercase `.SVG` now crops and
  thumbnails to a real JPEG, and a file named exactly `.svg` keeps its SVG-parser routing.
  Regression audit L5, L6. [#1243](https://github.com/owen2345/camaleon-cms/pull/1243).

- **Fix:** The admin media browser paginates at the database again instead of loading a folder's
  entire media list into memory and re-checking every image's thumbnail on disk per page view;
  the legacy-thumbnail repair now runs only over the rendered page. Sites with large media folders
  load the media manager far faster. Regression audit M27.
  [#1242](https://github.com/owen2345/camaleon-cms/pull/1242).

- **Notes for upgraders (two documented behaviors, no code change):**
  - **Assets:** the engine's list of plugin/theme asset roots to precompile is a boot-time
    snapshot. A Sprockets-3 host app that appends its own `config.assets.paths` in an initializer
    running *after* the engine's will not have those files precompiled in production. Drive
    precompilation from `manifest.js` (as the maintained host apps do) rather than appending paths
    after boot. Regression audit M29.
  - **Template lookup:** an explicit `render prefixes: [...]` whose list is entirely theme-scoped
    (only `themes/<slug>/views` and/or `camaleon_cms/default_theme`) is looked up in exactly those
    prefixes — the controller/global prefixes are deliberately not merged, so a theme partial
    cannot resolve another site's per-site-override or a plugin's views. A render that needs a
    controller-owned template must include a non-theme prefix in the list. Regression audit M30.

- **Security fix:** An authenticated uploader without the `media_unfiltered_upload` permission
  could use a `before_upload` hook to substitute bytes the content scanner never saw, since the
  hook runs after the scan and the persisted IO is what it leaves behind. The pipeline now
  re-scans the substituted content for untrusted uploaders. Same PR also: a blank or `0`
  "Max file size" setting no longer rejects every upload and crop (and the size gate coerces a
  numeric-string limit instead of raising on it); media-manager upload errors
  again run the `on_translation` hook so plugins can override them; and the content scan folds
  its 58 event-handler patterns into one pass. Regression audit N2/M26/M24/M25.
  [#1241](https://github.com/owen2345/camaleon-cms/pull/1241).

- **Note for upgraders:** Dropping a new plugin or theme folder into the app and then activating
  it from the admin now requires a server restart before it is discovered — the Plugins/Themes
  admin index no longer rescans the filesystem on each view (changed in #1163). Restart the app
  after adding a plugin/theme directory. Regression audit M28.

- **Security fix:** The two admin theme-settings paths that still saved custom-field values raw
  — the `theme_fields` param and the bundled `new` theme's settings-save hook — now go through
  the same allowed-slugs filter as every other admin custom-field save (added in 2.9.2), closing
  a mass-assignment gap reachable by any role granted the theme-settings capability.
  [#1240](https://github.com/owen2345/camaleon-cms/pull/1240).

  **Notes for upgraders:**
  - Values submitted through theme settings for slugs that are not registered theme fields are
    no longer persisted; registered fields are unaffected.

- **Fix:** An admin custom-field save whose submitted slugs were all unregistered under the
  target scope wiped the object's stored values (the allowed-slugs filter, added in 2.9.2,
  reduced such a payload to an empty-but-present shape that made the value writer clear
  everything and write nothing). The filter now drops those empty groups, so the save is a
  no-op instead. Affected every admin custom-field save path.
  [#1240](https://github.com/owen2345/camaleon-cms/pull/1240).

- **Fix:** User custom fields work again for host apps configuring a namespaced `user_model`
  (e.g. `'Admin::User'`): the settings form's users placement option, the user edit page's
  field-group read, and the save filter's allowed-slugs lookup now all derive the demodulized
  user-model scope name the association scope uses, so submitted user field values are no longer
  silently discarded (broken since 2.9.2). Engine-default and top-level `User` installs are
  unaffected. Regression audit N5. [#1239](https://github.com/owen2345/camaleon-cms/pull/1239).

  **Notes for upgraders:**
  - Namespaced-`user_model` installs run `bin/rails camaleon_cms:demodulize_user_field_groups`
    once after upgrading: it re-keys user field groups stored under the old qualified placement
    so they stay visible and editable. Idempotent; a no-op everywhere else.
  - After that task runs, rolling back to 2.9.2 hides those groups on the user edit page until
    re-upgrade (data intact — same class of hazard as the `Widget::Assigned` note below).

- **Fix:** The `object_class` scope naming for metas, custom fields, and field groups returns to
  the demodulized 2.9.2 contract (`'Main'`, `'User'`), reverting an unreleased rename to
  prefix-qualified names that stranded every row existing installs had written; the widget admin
  literals move with it, keeping widget custom-field values saving correctly (broken
  2.8.x–2.9.2, now spec-pinned end to end). Also removes the bulk-delete cascade on the
  definition associations: teardown belongs to the placement hook (which destroys groups with
  callbacks), and on models without that hook the cascade raw-deleted definition rows while
  orphaning their fields and option metas. Regression audit M9/M8/N4.
  [#1238](https://github.com/owen2345/camaleon-cms/pull/1238).

  **Notes for upgraders:**
  - Rows written by unreleased master-tracking installs under the short-lived prefixed scopes
    (`'Widget::Main'`, `'Admin::User'`) are not migrated; released installs are unaffected.

- **Rollback hazard (documentation):** Sidebar widget assignments created on this version are
  stored with the compact `Widget::Assigned` discriminator. 2.9.2 reads only the full
  `CamaleonCms::Widget::Assigned` name, so rolling back to 2.9.2 hides every assignment created
  here (they reappear on re-upgrade — the upgrade direction reads both spellings), and raw SQL
  filtering on the old value misses rows written here. Regression audit M7.

- **Fix:** Three legacy model-API surfaces restored: `Media.find_by_key` (as an alias of
  `by_key` — the rename left legacy callers raising `NoMethodError`), `Post#unassign_category`
  (with its category-counter refresh made reliable on posts whose categories association is
  already loaded), and the default ascending-id ordering on `NavMenu`/`NavMenuItem` (rendered
  menu order was and stays `term_order`). Also documents the `ActiveRecordExtras` removal (see
  the entry below) and corrects the [#1222](https://github.com/owen2345/camaleon-cms/pull/1222)
  claim about slug-uniqueness scope: it is site-wide across post types, now spec-pinned.
  Regression audit M5/M6/M10/M4/M11.
  [#1237](https://github.com/owen2345/camaleon-cms/pull/1237).

- **Removed:** The `ActiveRecordExtras` mixin and with it the `update_or_create`,
  `update_or_create!`, and `assign_or_new` model methods, formerly available on every Camaleon
  model. External code that called them should use the Rails idiom instead:
  `Model.find_or_initialize_by(lookup_attrs).tap { |r| r.assign_attributes(extra_attrs); r.save }`
  (or `save!`). The 2026-08 ecosystem sweep found no plugin, theme, or host app calling these
  methods; this note exists because the removal was previously undocumented. Regression audit M4.

- **Fix:** Three session-adjacent regressions: the admin login/register/forgot-password pages
  render in the site's language again (with `?locale=` honored when the site offers it, falling
  back silently otherwise); same-host `return_to` destinations are followed regardless of host
  letter case and emitted with the canonical host; and malformed `?user_id[]=` requests on admin
  user routes no longer crash with a 500 or wrongly deny self-edits — a non-scalar `user_id` is
  ignored and the route target wins. Post-review hardening on the same PR: non-scalar locale
  parameters (`?locale[]=`, `?cama_set_language[]=`) are likewise ignored on the admin session
  pages and the site frontend instead of crashing with a 500, and a scalar `?locale=` naming a
  language the site does not offer now renders the site's 404 page (in the site's own language)
  instead of failing with a template error. Regression audit M15/M17/M14.
  [#1236](https://github.com/owen2345/camaleon-cms/pull/1236).

- **Security fix:** Draft autosaves could be forged to parent a new draft under an arbitrary
  existing post (a client-supplied `post[post_parent]` survived validation), and an edit-own-only
  user was locked out of autosaving their own post once someone else's autosave had created its
  draft. `post_parent` is now create-only, derived solely from the validated `post_id`, and draft
  buffers are per-user, authorized against the post being edited — no request can read, overwrite,
  re-parent, or detach another user's buffer. Regression audit M12/M13.
  [#1235](https://github.com/owen2345/camaleon-cms/pull/1235).

  **Notes for upgraders:**
  - Each editor now keeps a private autosave buffer per post, so the admin drafts list can show
    one draft per editing user; any successful save of a post still removes all of its buffers.
  - Roles holding only `edit_other` can now autosave posts they can edit but not author
    (previously the first autosave of such a post was silently denied).

- **Fix:** Restores seven admin and frontend runtime-compatibility contracts broken by the
  `CurrentRequest` and admin-menu refactors: the 2-arg `post_type_list_taxonomy` (which rendered empty
  taxonomy columns in overridden admin posts-index views), signed-out `cama_current_user` memoization,
  quote-safe admin menu `data-*` attributes (the admin Menus tooltip), inline formatting in plugin menu
  titles, `cf_add_model`'s placement-dropdown models, the `@_admin_menus.delete` menu-removal idiom, and
  the frontend legacy-ivar read fallback for `the_title`/`is_home?`/SEO helpers. Regression audit
  M16/M18–M20/M22/M23. [#1234](https://github.com/owen2345/camaleon-cms/pull/1234).

- **Fix:** On multisite installs, background and cross-site email (password reset, email confirmation,
  admin notifications) raised `NameError` during delivery and sent nothing — `SiteHelper#current_site`
  stopped honoring the `@current_site` that `HtmlMailer` sets, so a delivery with no request fell
  through to a request-only branch. Restored; single-site installs were unaffected.
  [#1233](https://github.com/owen2345/camaleon-cms/pull/1233).

- **Docs:** Codified the security-capability-gating rule — a security-sensitive action is admin-only by
  default and gated for non-admins by a dedicated, off-by-default, fail-closed role permission
  (authorization, never a path/filename/flag proxy, and never fail-open). Adds the
  `security-capability-gating` OpenSpec capability, a "The gating rule" section in
  `docs/security/permissions.md` with a recipe for adding a new gated capability, and a
  `docs/ai/criteria.md` checkpoint. No engine changes; the four existing permissions are cited as
  templates. [#1231](https://github.com/owen2345/camaleon-cms/pull/1231).

- **Docs:** Removed the defunct Autocomplete plugin (`gaelfokou/cama_autocomplete` — repository and
  gem no longer exist) from the README plugin list and the example Gemfile, and recorded the external
  plugin/theme binding surface as the `ecosystem-plugin-bindings` OpenSpec capability with a
  `docs/ai/ecosystem.md` inventory. [#1229](https://github.com/owen2345/camaleon-cms/pull/1229).

- **Security fix:** A user with only the `media` permission could upload an SVG the SVG ruleset
  accepted, then re-crop it under an `.html` name to have the identical bytes served as
  `text/html` from the site origin, unscanned — the re-scan exemption added in
  [#1226](https://github.com/owen2345/camaleon-cms/pull/1226) keyed on the source path while the
  ruleset and the served content type key on the caller-supplied output name. Scanning is now
  gated on a new `media_unfiltered_upload` role permission instead. Also fixes seven defects
  found reviewing [#1223](https://github.com/owen2345/camaleon-cms/pull/1223)–[#1227](https://github.com/owen2345/camaleon-cms/pull/1227).
  [#1228](https://github.com/owen2345/camaleon-cms/pull/1228).

  **Notes for upgraders**

  - **Uploads by anyone but an administrator are scanned whatever their source**, including files
    already stored under `public/`, so re-cropping an existing file is scanned again. Grant
    **Allow unscanned media uploads** (Manager Permissions) to a role that needs the previous
    behaviour; no default role but `admin` holds it, and existing role metas read as not granting
    it. See `docs/security/permissions.md`.
  - SVGs containing `form`, `meta`, `base`, `style` or `link` are now refused for those users.
  - `rake camaleon_cms:reassign_orphaned_comments` no longer rewrites genuine guest comments —
    only rows with no author string, or a user id that no longer exists. If you already ran it,
    guest comments were reassigned to the anonymous user; display is unaffected, since a stored
    author name takes precedence.
  - Deleting a user no longer aborts when one of their comments has an unresolvable post; such
    comments are skipped and reported by the task above.

- **Fix:** Validating a post without an explicit slug raised `FrozenError` instead of reporting
  `Slug can't be blank`, so creating posts programmatically (imports, seeds, jobs, console) was
  impossible. `String#translations` memoized its parsed locales in an instance variable on the
  receiver, which Ruby 3.4's frozen `nil.to_s` cannot carry; frozen strings now parse without
  memoizing. Long-standing, not a regression.
  [#1227](https://github.com/owen2345/camaleon-cms/pull/1227).

- **Fix:** The upload hardening in [#1198](https://github.com/owen2345/camaleon-cms/pull/1198)–[#1211](https://github.com/owen2345/camaleon-cms/pull/1211)
  rejected legitimate work: uploads staged outside `public/` or the system temp dir failed with
  `Invalid file path`, animated SVGs and re-crops of already-stored files were refused as
  malicious, and prose containing a word such as `data` before a colon tripped the scheme
  detector. Trusted server-side callers can now widen the allowed roots per call, animation
  elements are accepted, already-published sources are not re-scanned, and scheme detection
  matches the browser rule. [#1226](https://github.com/owen2345/camaleon-cms/pull/1226).

  **Notes for upgraders**

  - **Plugins, jobs and imports may pass `allowed_roots:`** to `upload_file`/`cama_tmp_upload`
    to stage files under `Rails.root/tmp`, `storage/`, or a mounted share. It applies to that call
    only and must come from application code — a request parameter cannot widen the roots, and
    request-driven uploads keep the default roots.
  - SVG event handlers (`onbegin`/`onend`/`onrepeat`), `script`, `foreignObject` and `handler`
    remain rejected; only the `animate`/`set` elements themselves are allowed.
  - HTML uploads are still refused. Re-permitting them needs a server-side extension policy
    first, since `formats` is client-supplied and uploads are served same-origin.

- **Fix:** Save-time post-content sanitization ([#1206](https://github.com/owen2345/camaleon-cms/pull/1206))
  destroyed legitimate markup for untrusted authors — the default allowlist has no table or figure
  elements and drops `id`/`style`/`target`/`rel` — and sanitized every programmatic save with no
  opt-out. Untrusted `Post#content` now keeps structural, non-executable markup (tables, figures,
  `u`/`s`/`hr`, and `id`/`style`/`target`/`rel`/`colspan`/`rowspan`) while still stripping scripts,
  iframes, event handlers, and `javascript:`/style-expression payloads. Also restores activation of
  the bundled `camaleon_first` theme, which 500'd on a `helper.capture` call in controller context.
  [#1225](https://github.com/owen2345/camaleon-cms/pull/1225).

  **Notes for upgraders**

  - **Trusted server-side code can bypass sanitization per record** with
    `post.unfiltered_content!` before save (imports, seeds, plugin pipelines). It has no `=`
    writer, so it is not mass-assignable and request parameters cannot set it.
  - Role gating is unchanged: admins and roles holding `post_content_unfiltered_html` still store
    raw HTML; the Editor default is still excluded. Content stripped before this release is not
    restored — re-add it and it now persists.

- **Fix:** Fallout from the native-STI conversion ([#1173](https://github.com/owen2345/camaleon-cms/pull/1173),
  which shipped with no changelog entry): rows with custom `taxonomy`/`post_class` values raised
  `SubclassNotFound` on read and create — they load and save as the base class again; deleting a
  user orphaned their comments (the anonymous-user reassignment had become dead code, and comment
  rendering then crashed) and destroyed their widgets — both restored to 2.9.2 behavior; and wrong
  `inverse_of` declarations made `.owner` raise on taxonomies, post types, and post tags (and on
  widgets for custom `user_model` installs), and overwrote menu items' parent with the Site on
  `site.nav_menu_items` loads. [#1224](https://github.com/owen2345/camaleon-cms/pull/1224).

  **Notes for upgraders**

  - Installs that deleted users while running a post-2.9.2 master build should run
    `rake camaleon_cms:reassign_orphaned_comments` once: comments whose user is gone are
    reassigned to each site's anonymous user; comments with an existing user are untouched.
  - Posts of a deleted user with no surviving admin now keep `user_id` NULL (2.9.2 left a
    dangling id); display already handled both.

- **Fix:** Six high-severity regressions introduced after 2.9.2, found by a full-range audit and
  each pinned by a spec that reproduced it: engine boot failed on production hosts that serve
  static files from nginx/Apache instead of Rails; one installed plugin or theme without a
  `helpers` key in its config crashed every request; `GET /search` 500ed because `ct` was
  unreachable on controllers, which also broke plugins calling `current_plugin`; frontend search
  matched nothing for mixed-case queries on PostgreSQL and ignored an empty result set from the
  `on_render_search` hook; `/sitemap.html` crashed for any site with a category and ignored the
  `on_render_sitemap` skip lists; and login, password reset, and `site.the_user` became
  case-sensitive. All six restore the 2.9.2 behavior.
  [#1223](https://github.com/owen2345/camaleon-cms/pull/1223).

- **Fix:** Slug-uniqueness validation was silently inert on Rails 7.0+. `UniqValidator` and
  `PostUniqValidator` registered errors by pushing onto `errors[:base]`, which modern Rails
  discards, so duplicate slugs and recursive page hierarchies saved without complaint; on
  Rails 6.1 the old pattern still worked. Errors are registered with
  `errors.add` again. [#1222](https://github.com/owen2345/camaleon-cms/pull/1222).

  **Notes for upgraders**

  - On Rails 7.0+, saves that duplicate a post slug already held by any non-draft, non-trashed
    post of the same site — the scope is site-wide, across post types and parents (this entry
    originally understated it as "same parent and taxonomy") — or that create a looping page
    hierarchy, fail validation again, matching what Rails ≤ 6.1 installs always enforced.
  - Records duplicated while the validator was inert are not rewritten; they surface the
    "requires different slug" error the next time they are edited.

- **Tests:** Feature specs now sign in by setting the auth cookie instead of driving the login
  form, and the sign-in actually verifies credentials — the old flow's "Welcome" assertion was
  satisfied by the login page itself, so failed logins passed silently. The form-driven flow lives
  on in `admin_form_sign_in`, covered by dedicated sign-in examples.
  [#1221](https://github.com/owen2345/camaleon-cms/pull/1221).

- **Tests:** The suite now installs a single shared Camaleon site per run instead of a full site
  before nearly every example, cutting a local full run from ~18 minutes to ~5. Test-only change:
  specs get the shared site through `init_site` and the factories, and `init_site(fresh: true)`
  keeps a per-example site for multi-site UI specs.
  [#1220](https://github.com/owen2345/camaleon-cms/pull/1220).

- **Fix:** Admin headings and tooltips showed raw HTML entities in place of the characters they
  encode, so a site named `Ben & Jerry's` read `Ben &amp; Jerry&#39;s`. Affected the site settings
  page, the post edit form, the sites form, the categories and tags indexes, and the custom fields
  category select. A category tooltip additionally read `&Amp;`, a corrupted entity rather than a
  doubled one. [#1219](https://github.com/owen2345/camaleon-cms/pull/1219).

  **Notes for upgraders**

  - **`cama_pluralize_text` returns an `ActiveSupport::SafeBuffer` when given one.** It propagates
    the safeness of its input and never adds it, so an unsafe input still yields an unsafe result
    and no caller becomes less safe than before.
  - **`the_title` still escapes its output.** The contract that themes and plugins rendering titles
    through `raw` depend on is unchanged, and the SEO surface was checked and is unaffected. Theme
    authors need change nothing.

- **Security fix:** Stored XSS in two server-generated HTML fragments. `PostDecorator#the_status`
  and `CustomFieldGroup#get_caption` assembled markup by string interpolation outside a view and
  admin templates rendered the result through `raw`, neither escaping the values it spliced in. A
  contributor could poison a post's status; a nav menu or widget manager could poison a field group
  caption. The admin panel is same-origin with the frontend, so either executed with an
  administrator's session. `TermTaxonomyDecorator#the_status` was hardened the same way, though it
  was not exploitable. [#1218](https://github.com/owen2345/camaleon-cms/pull/1218) — thanks, Enrik
  Mustafa: pressing the case for an already-fixed vulnerability is what prompted the re-check that
  found these two.

  **Notes for upgraders**

  - **A post whose status is not one of the five canonical values now renders it as visible escaped
    text instead of executing it** — which is how an operator spots a row poisoned before the
    upgrade. Non-canonical statuses are supported deliberately, so nothing is rejected on write and
    no data is rewritten.
  - **Output for legitimate data is byte-identical**, so a theme matching on the rendered status
    label or field group caption is unaffected. Both methods now return an
    `ActiveSupport::SafeBuffer`.
  - **The externally reported "Stored XSS via Draft Post Title" is not what this addresses.** It is
    not reproducible against 2.9.2 or later, having been fixed by
    [#1143](https://github.com/owen2345/camaleon-cms/pull/1143) and
    [#1139](https://github.com/owen2345/camaleon-cms/pull/1139).

- **Security fix:** Cross-site custom field group injection. A custom field group carries both a
  `parent_id` (which site owns and administers it) and an `object_class`/`objectid` pair (which
  record's admin page displays it). `Admin::Settings::CustomFieldsController` split the submitted
  `assign_group` parameter straight into the placement columns without checking ownership, and
  placement reads are not scoped by site — so a user who could manage custom fields on one site
  could stamp a group with another site's theme, menu, plugin or post type id and have it render
  there. The target site's own field-group list is scoped by `parent_id`, so the group stayed
  invisible to its administrators, who could neither find nor delete it, while values entered
  against those fields persisted on that site's records.
  [#1217](https://github.com/owen2345/camaleon-cms/pull/1217).

  `custom_fields` is a role-manageable resource, so the privilege required was "can manage custom
  fields on some site", not "is a superuser". Only multi-site installs with mutually untrusted site
  administrators were affected; single-site installs were not. `Site` placements were already
  covered by [#1216](https://github.com/owen2345/camaleon-cms/pull/1216), and `User` placements
  were never affected.

  **Notes for upgraders**

  - **Submitting a placement the current site does not own is now refused** with a form error.
    Classes with a single legal target — `Site`, the configured user model, and models registered
    through the `custom_field_custom_models` hook — are validated against the current site's id
    rather than an allow-list of class names, so plugins contributing custom models keep working.
  - **`rake camaleon_cms:rehome_cross_site_field_groups`** repairs groups already injected, moving
    them to the site whose pages they were rendering on so that site's administrators can see and
    delete them. Nothing is deleted, and groups whose placement target no longer exists are skipped.
    **Multi-site operators should review their field-group lists after running it — a group that
    appears newly is one that was already rendering on their pages.**
  - **The read paths are unchanged.** They still resolve placement without a site filter; the fix
    is the write-side guard plus the repair task. Rationale in the change's `design.md` D2.

- **Fix:** The site settings form rendered every custom field group in the site, not just the ones
  meant for the site. Groups belonging to posts, categories, themes or menus can hold required
  fields, so jQuery validation refused to submit until an administrator filled in data that does not
  apply to the site — and `site_saved` discarded that data anyway, since it permits only slugs of
  fields under `object_class: 'Site'` groups. A field group carries both a `parent_id` (which site
  owns it) and an `object_class`/`objectid` pair (which record's admin page shows it); `Site` was the
  only model reading the first where it should read the second.
  [#1216](https://github.com/owen2345/camaleon-cms/pull/1216), reported as
  [#1124](https://github.com/owen2345/camaleon-cms/issues/1124).

  Two latent defects go with it, both previously broken for sites only:
  `site.add_custom_field_group` raised `Object class can't be blank`, and `site.set_field_value`
  could bind to a field belonging to another content type when the two shared a slug.

  **Notes for upgraders**

  - **`site.get_field_groups` is narrower.** It now returns only the groups placed on the site,
    matching its own documented contract ("get custom field groups for current object"). A plugin
    or theme using it as "every group in this site" should use `site.custom_field_groups`, which is
    unchanged and still means exactly that.
  - **A site whose only groups belonged to other content types loses its Custom Configurations
    tab.** That is the fix rather than a regression: those fields could not be saved.
  - **`rake camaleon_cms:backfill_site_field_group_objectid`** repairs site field groups stored with
    a `NULL` `objectid`, which the placement-scoped read would otherwise hide. `objectid` has no
    presence validation, so such rows are constructible, but no shipped code path creates them —
    only an installation that built site groups by hand instead of through
    `add_custom_field_group` has anything to repair. A Rake task rather than a migration, so a
    data-only repair does not force `spec/dummy/db/schema.rb` to be regenerated.

- **Security fix:** HTML injection in `Hash#to_attr_format` and in the bundled `cama_contact_form`
  plugin's form rendering. `to_attr_format` escaped attribute values with `gsub('"', '\"')` — a Ruby
  string escape in an HTML context, where a backslash escapes nothing — and interpolated attribute
  *names* verbatim, so a key of `x onfocus=alert(1) y` rendered as three attributes. Separately, the
  contact form built its markup by raw string interpolation and emitted it through `raw`, so both an
  unauthenticated visitor's resubmitted values and every form-definition field could inject script.
  The admin panel is same-origin with the frontend, so script landing there runs with an
  administrator's session — a privilege escalation from any role holding `:manage, :plugins`.
  Requires `cama_contact_form` 0.1.12.
  [#1215](https://github.com/owen2345/camaleon-cms/pull/1215) — thanks, Amir Aliu and Enrik Mustafa,
  for reporting this. Gated positions and the permission's exact scope: `docs/security/permissions.md`.

  **Breaking changes**

  - **The contact form refuses unsafe content instead of rewriting it.** Nothing is escaped or
    sanitized: a form's content is stored and delivered exactly as written, or the save is refused
    and the author told which setting to fix. An author holding `contact_form_unfiltered_html` is
    unaffected. A visitor's submission is likewise refused whole rather than escaped. Ordinary
    writing still passes for both — `Tom & Jerry`, `&nbsp;`, `<br/>`, uppercase tags, single-quoted
    attributes, and `Fish & Chips <today>` from a visitor.
  - **`to_attr_format`** emits `&quot;` where it emitted `\"`, and drops pairs whose key is not a
    valid HTML attribute name (`/\A[a-zA-Z_:][-a-zA-Z0-9_:.]*\z/`). A plugin or theme relying on the
    old output to inject markup through a value or a name will stop working — that is the fix.
  - **`to_attr_url_format`** emits `value.to_s.inspect`; it did not escape backslashes before. Not a
    security fix, and it has no callers in this repo.
  - **The role editor** gains "Allow unfiltered HTML in contact forms", off for every role but
    `admin`. It also now renders any `admin`-slugged role's permissions as held and **locked**, which
    is what `can :manage, :all` has always meant. Role permissions are seeded once, when the site is
    created, so on an existing site every key added to `ROLES` since then was rendering unchecked and
    reading as "denied to administrators". Deriving the display from the role needs no data
    migration, and none should be written — that meta is never read for an administrator. The
    controller declines to write it for such a role too, on the same predicate: a disabled checkbox
    is not submitted, so locking the view alone would have cleared the stored set on the next save.
  - **[#1206](https://github.com/owen2345/camaleon-cms/pull/1206)'s permission is renamed** —
    `allow_unfiltered_html` → `post_content_unfiltered_html`, and its ability likewise — so each
    identifier names its subject. No migration: #1206 has not shipped in any release.
  - **The `cama_contact_form` dependency is raised to `~> 0.1.12`**, where the plugin-side fix lives.
    Raised rather than left at `~> 0.1.0`, whose range still admits the vulnerable 0.1.0 from
    2022-12-27. Nothing to add to a host application's `Gemfile`; `bundle update camaleon_cms` is
    enough. 0.1.10 and 0.1.11 are tagged on GitHub but describe two designs reversed in review, and
    neither reached RubyGems.

  Existing stored content is not re-checked: a form keeps rendering whatever it holds until someone
  saves it again, at which point the gate applies. One caveat worth stating because it reads like a
  guarantee and is not — *formatting* markup in a dropdown option label does not render, since a
  browser drops `<b>` and the like inside `<option>`, but `<script>` and `<template>` both survive
  parsing there, so that position is gated exactly like every other.

- **Security bumps** picked up while re-resolving `cama_contact_form`: rails 8.1.3 → 8.1.3.1,
  concurrent-ruby 1.3.7 → 1.3.8, erb 6.0.4 → 6.0.6, json 2.20.0 → 2.21.1, net-imap 0.6.4.1 → 0.6.6.
  Bundler moves 2.7.2 → 4.0.17, and both CI workflows pin `rubygems: 4.0.17` to match — RubyGems
  ships Bundler at its own version, so a runner on 3.7.2 would be asked to run a lock pinned to
  Bundler 4. [#1215](https://github.com/owen2345/camaleon-cms/pull/1215)

- **Developer tooling:** Document when an OpenSpec change is archived. `AGENTS.md` listed `/opsx:archive` with no timing and `docs/ai/workflows.md` Phase 4 did not mention it at all, so the close-out sequence read as if archiving were a post-merge step. It is not: the archive is committed on the branch as part of the PR, so `master` never carries a completed-but-unarchived change and every task is checked off before merge. Both documents now say so, and Phase 4 lists it as an explicit step before the quality gate. [#1214](https://github.com/owen2345/camaleon-cms/pull/1214)

- **Developer tooling:** Correct the skip-ci guidance in `docs/ai/workflows.md`. The rule for docs-only commits read as an unconditional instruction to omit the marker on the Phase 4 changelog commit, when omitting it is only correct while the PR has not yet had a full check run. Because that commit lands *after* the PR is opened — and therefore after an earlier push already triggered CI — following the rule as written duplicated the entire test matrix to validate a `CHANGELOG.md` edit. The guidance is now a single per-push question with both answers spelled out, states explicitly that "lands last" is not the condition, and adds what to do when a docs-only commit has already been pushed without the marker: cancel the stale runs on the previous SHA, not the new ones. [#1214](https://github.com/owen2345/camaleon-cms/pull/1214)

- **Fix:** Report an unresolvable target in `Admin::UsersController#updated_ajax` in the action's own error format. The endpoint already answered its other failures with a status plus a short text body — `400` for a missing `password` parameter, `422` for a validation error — but let a lookup that found no record fall through to the framework's default HTML error page. It now rescues `ActiveRecord::RecordNotFound` and reuses the existing `camaleon_cms.admin.users.message.error` translation, catching that class only and never `StandardError`, so a genuine lookup failure still surfaces instead of being reported as a missing user. All three failure paths were also converted from `render inline:` to `render plain:`: `inline:` compiles its argument as an ERB template, which buys nothing for a fixed message and is a template-injection sink on the `422` path, whose body is assembled from validation messages and can carry user-influenced text. This completes a migration started in `67a43f1b`, which touched this file but changed only a comment. This is not a security fix: `validate_role` admits only the target themselves or a holder of `:manage` on `:users`, so the lookup was never an existence oracle and needs none of the response-shape uniformity that [#1213](https://github.com/owen2345/camaleon-cms/pull/1213) required for `GET /admin/profile`. [#1214](https://github.com/owen2345/camaleon-cms/pull/1214)
  - **Behavior change:** an unresolvable target keeps its `404` — `ActiveRecord::RecordNotFound` already mapped to `:not_found` — but the body is now the "Not found user." message as text rather than an HTML error page.
  - **Behavior change:** the `400` and `422` failure responses keep their exact bodies but now carry `Content-Type: text/plain` instead of `text/html`. The bundled admin modal is unaffected — it renders the body only from a `$.post` success callback, which never fires for these statuses.

- **Developer tooling:** Capture the canonical target-user resolution invariant for `Admin::UsersController` as the `user-target-resolution` OpenSpec capability, and close the regression-coverage gap it exposed. The rule that closed the account takeover in [#1185](https://github.com/owen2345/camaleon-cms/pull/1185) — that the authorization filter and the record lookup must resolve the target through one canonical helper, so the record authorized is always the record acted upon — was recorded only in a commit message and a single regression spec covering one endpoint. Nothing injected `?user_id=` on a member route, and the one request spec touching `update` stubs `validate_role` outright, so half the surface the invariant protects was untested. New request specs cover the member routes (`update`, `destroy`, `impersonate`) and were validated by reverting the fix two ways: restoring the original parameter precedence, and separately making `set_user` diverge from `validate_role` — the latter lets a low-privilege caller delete another user. No application behavior changed. [#1214](https://github.com/owen2345/camaleon-cms/pull/1214)
  - **Documented behavior:** on the member routes (`/admin/users/:id`) the path segment lands in `params[:id]`, so an injected `user_id` takes precedence over it and `PATCH /admin/users/A?user_id=B` edits **B**. This is not a privilege escalation — the filter and the lookup still resolve the same user, and any caller who passes the filter for that user may act on them — but it is now pinned by a spec rather than left to be rediscovered.

- **Security fix:** Close a user-existence oracle left by the profile IDOR fix in [#1197](https://github.com/owen2345/camaleon-cms/pull/1197). That fix authorized against the *loaded* record (`@user.id`), which forced the lookup to run first — and `current_site.the_user` returns `nil` for an unknown id, so `.object` raised `NoMethodError` before `authorize!` was ever reached. A denied low-privilege caller therefore got a `500` for a nonexistent `user_id` but a `302` for an existing one, letting them still enumerate which user ids exist by walking sequential integers (no profile data disclosed — that half stayed fixed). `profile` now decides authorization from the request parameter *before* loading anything, matching how `validate_role` already guards every other action in the controller, so all rejected lookups are indistinguishable. The same reordering plus a nil guard also ends the unhandled `500` that *any* caller, including a legitimate admin, got for a nonexistent, deleted, non-numeric, or array-shaped `user_id`; those now redirect with the existing "Not found user." message, reusing the `set_user` idiom and adding no new translation keys. [#1213](https://github.com/owen2345/camaleon-cms/pull/1213)

- **Refactor:** De-duplicate the two uploader entry points. `CamaleonCms::RuntimeUploaderConcern` (controllers) and `CamaleonCms::UploaderHelper` (views, ActiveJobs, standalone objects) carried 349 byte-identical lines across 18 methods, so every upload fix had to be written twice and `Metrics/ModuleLength` had been raised three times to accommodate them. The shared bodies now live in `CamaleonCms::UploaderPipeline`, `CamaleonCms::UploaderImageProcessing`, and `CamaleonCms::UploaderSupport` under `lib/camaleon_cms/`, which both entry points include — the same pattern as `UploaderPathSecurity` and `UploaderContentSecurity`. Both entry points keep their full public API: every method retains its name, arity, visibility, and return value, so host apps, plugins, and themes that include either module are unaffected. User-facing upload messages keep their per-context pipeline through a small seam, so `UploaderHelper` still translates via `ct`/`cama_t` and the `on_translation` hook can still override upload error text. [#1212](https://github.com/owen2345/camaleon-cms/pull/1212)
  - **Behavior change:** `cama_tmp_upload` now decides whether a `data:` upload supplied a filename from its own `:name` argument instead of `params[:name]`. Identical on every controller path, since the media controller passes `name: params[:name]` through; it additionally makes the helper's `data:` branch work in an ActiveJob, where `params` does not exist and the call previously raised `NameError`.
  - **Behavior change:** `upload_file` now deep-symbolizes the `settings` hash on the controller path too, where it was previously shallow. Unobservable for the documented settings keys, which are all scalars; it can only surface for a caller passing a nested *string*-keyed hash and reading it back as a String, including from a `before_upload`/`after_upload` hook.

- **Security fix:** Prevent rejected media uploads from persisting in the web-served staging directory — a user holding only the `media` permission could `POST /admin/media/actions` with `media_action=crop_url` and a `data:` payload, receive `Potentially malicious content found!`, and still have the payload written to `public/tmp/<site_id>/` and served same-origin, defeating the scan that reported the rejection. Content is now scanned *before* the staging write (the decoded bytes are already in memory, so this costs no extra copy), and any staged file is removed when the upload fails for any reason, via a guard that can only delete inside the staging root. The same request was also unbounded: `filesystem_max_size` was only checked after staging and `cama_tmp_upload`'s own size check was dead code because no media controller path passed `:maximum`, so a `data:` payload of any size was decoded and written to disk first — the limit now defaults to the site setting and is applied to the base64 length before decoding. Additionally completes the non-SVG content denylist, which 14 confirmed payloads bypassed: content is normalized before matching (HTML entities decoded in a bounded 5-pass loop matching `UserUrlValidator`, NUL/C0 controls stripped), `vbscript:` is blocked alongside `javascript:`/`data:`, schemes tolerate whitespace injected between their characters (`jav<TAB>ascript:`), the tag delimiter widened from `[\s>]` to `[\s/>]` so `<script/src=…>` no longer slips through, `meta`/`style`/`form`/`applet`/`frame`/`frameset`/`link`/`template`/`portal`/`marquee`/`math` were added to the blocked elements, and a long-standing typo that listed `onunloadonsubmit` as a single token — leaving both `onsubmit=` and `onunload=` unmatched — was split into two entries. [#1211](https://github.com/owen2345/camaleon-cms/pull/1211) — thanks, Lukman Azri, whose report triggered the triage that surfaced this.
  - **Behavior change:** the stricter scanner is fail-closed, so a document containing HTML-escaped code examples (e.g. `&lt;script&gt;`) is now rejected, because normalization decodes the entities before matching. Content like that must be hosted outside the upload pipeline.
  - **Behavior change:** `data:` uploads larger than `filesystem_max_size` (default 100 MB) are now rejected. This restores the documented, intended limit rather than introducing a new one.
  - **Upgrade note:** this fix does not remove files already orphaned in `public/tmp/` by earlier versions. Clear that directory once on upgrade — on a long-running 2.9.2 install it may already hold planted payloads.

- **Developer tooling:** Restructure AGENTS.md docs tree for progressive disclosure — remove never-used knowledge/decision/quality-gate process docs superseded by OpenSpec, consolidate reference docs, and add a `CLAUDE.md` import shim, [#1208](https://github.com/owen2345/camaleon-cms/pull/1208)

- **Developer tooling:** Add OpenSpec skills for Claude, [#1193](https://github.com/owen2345/camaleon-cms/pull/1207)

- **Security fix:** Fix stored XSS via unsanitized post content — add server-side HTML sanitization to `Post#content` at save time with role-based allowlisting (new `allow_unfiltered_html` permission key), so untrusted contributors cannot inject arbitrary scripts into `raw @post.the_content` template output. Also fix data loss from `normalize_attrs` on plain-text and structured-data fields (Meta#value, User#name, Site#name, etc.) where `sanitize()` silently stripped angle-bracket content such as `email_from: "Name <user@domain.com>"`. Additional hardening from code review: escape taxonomy names in `TermTaxonomyDecorator#the_title` and keep save-time sanitization on `NavMenuItem#name` (both reach `raw`/`html_safe` breadcrumb and nav-menu sinks), escape commenter names in the admin comment-moderation view, exclude `allow_unfiltered_html` from the default Editor role so only admins bypass sanitization, fail closed (sanitize) when the site context is missing instead of raising, and replace the `!--`/`--!` translation-tag sentinels with collision-resistant markers so user-typed text can no longer inject stray HTML comment delimiters. [#1206](https://github.com/owen2345/camaleon-cms/pull/1206) — thanks, Theodosis Paidakis, for reporting this.

- **Security fix:** Add defense-in-depth URL validation to the crop action — validate user-supplied HTTP/HTTPS URLs before passing them to the temporary upload pipeline, via a shared `cama_upload_url_error` helper also used by `crop_url` and the `upload` action (closing an unvalidated `upload` → `upload_file` URL path). Same-site URLs (read from the local filesystem, never fetched) are checked for path traversal only, so legitimate values are no longer wrongly rejected by DNS/SSRF/HTML-sanitize checks — hosts resolving to loopback/private IPs (localhost, Docker, intranet), non-resolvable dev hosts, and multi-parameter query strings; remote URLs still get the full SSRF validation and are pinned to the validated IP to defeat DNS rebinding. Also catch multiply-encoded path traversal (e.g. `%252e%252e`) and ignore a trailing dot when matching same-site hosts. [#1203](https://github.com/owen2345/camaleon-cms/pull/1203) — thanks, Theodosis Paidakis, for reporting this.

- **Security fix:** Fix path traversal bypass in file upload guards — canonicalize paths with `File.expand_path` before prefix validation at all 4 sink locations, replace substring-based site URL detection with host+port comparison, harden the `data:` upload branch against `name`-based traversal writes, and add path traversal detection to `UserUrlValidator`. Also fixes the data URI upload regression from #1198 and a `crop_url` crash on uploads without a folder, extracts the shared guard logic into `UploaderPathSecurity`, and bumps `loofah` to 2.25.2 and `rails-html-sanitizer` to 1.7.1. [#1201](https://github.com/owen2345/camaleon-cms/pull/1201) — thanks, Jose Rivas (Zero Trust Offsec), for reporting this.

- **Security fix:** Fix SVG stored XSS via Nokogiri parse-based detection — replace regex denylist for SVG uploads with XML parser that resolves entities, blocks `script`/`on*`/`javascript:`/`data:`/embed tags, and disable XXE via `nonet`. Add Rack middleware serving SVGs under `/media/` with `X-Content-Type-Options: nosniff` and `Content-Security-Policy: script-src 'none'`, [#1199](https://github.com/owen2345/camaleon-cms/pull/1199) — thanks, Jose Rivas (Zero Trust Offsec), for reporting this.

- **Security fix:** Fix arbitrary server-side file read via media upload — validate path prefix before `File.open` in `upload_file` and `cama_tmp_upload`, coerce nil `formats` to `'*'`, and handle crop errors gracefully, [#1198](https://github.com/owen2345/camaleon-cms/pull/1198) — thanks, Jose Rivas (Zero Trust Offsec), for reporting this.

- **Security fix:** Fix profile IDOR in \`Admin::UsersController#profile\` — add inline \`authorize!\` check when viewing another user, so low-privilege users can no longer enumerate arbitrary user accounts. [#1197](https://github.com/owen2345/camaleon-cms/pull/1197) — thanks, Neo Andrew, for reporting this.

- **Security fix:** Fix improper authorization in draft autosave endpoint — scope draft lookups to post type, add \`authorize!\` checks before draft mutations, and validate \`post_parent\` against a real post, [#1196](https://github.com/owen2345/camaleon-cms/pull/1196) — thanks, Enrik Mustafa and Óscar Uribe, for reporting this.

- **Security fix:** Prevent SVG XSS bypass via missing animation event handlers (\`onbegin\`/\`onend\`/\`onrepeat\`) in file upload content filter. DRY duplicated \`UNSAFE_EVENT_PATTERNS\` into shared \`CamaleonCms::ContentSecurity\` module, [#1195](https://github.com/owen2345/camaleon-cms/pull/1195) — thanks, Mohamed Almuhaya, for reporting this.

- **Fix:** Restore legacy widget assignments, configured navigation order, and frontend plugin controller helper compatibility, [#1194](https://github.com/owen2345/camaleon-cms/pull/1194)

- **Developer tooling:** Add OpenSpec planning workflow and agent guidance, [#1193](https://github.com/owen2345/camaleon-cms/pull/1193)

- **Security bumps:** Bump json, puma to 8.0.2, rubocop to 1.88.1, zeitwerk to 2.8.2, and other gems on development and fix all new Rubocop offenses, [#1167](https://github.com/owen2345/camaleon-cms/pull/1186)

- **Security fix:** Prevent account takeover in `Admin::UsersController#updated_ajax` by unifying target-user lookup and authorization. [#1185](https://github.com/owen2345/camaleon-cms/pull/1185) — thanks, Lukman Azri, for reporting this.

- **Fix:** Restore TinyMCE editor icons in development, [#1183](https://github.com/owen2345/camaleon-cms/pull/1183)
  - sprockets-rails >= 3.5 registers `Sprockets::Rails::AssetUrlProcessor`, a `text/css` post-processor that rewrites every relative `url(...)` reference to a digested asset path. TinyMCE's bundled skin (`tinymce/skins/lightgray/skin.min.css`) references its icon font with relative urls such as `url("fonts/tinymce.woff")`, whose real logical path is `tinymce/skins/lightgray/fonts/...`. The processor cannot resolve them and rewrites them to an invalid root path (`/fonts/tinymce.woff`) that 404s, leaving the editor toolbar without icons.
  - Only surfaces in environments that compile assets on the fly (development): production ships the skin as raw static files via `tinymce.install = :copy`, bypassing Sprockets (and the processor) entirely. The processor must not be disabled globally, however, because other stylesheets (e.g. Bootstrap, whose glyphicon `@font-face` urls are relative) rely on it to produce resolvable asset paths. `config/initializers/assets.rb` now replaces it (when `config.assets.compile` is true) with a `TinymceSkinSafeAssetUrlProcessor` subclass that, for the TinyMCE skin only, first expands the skin's directory-relative font urls into full logical asset paths (prefixed with the skin's own logical directory) before delegating to the original processor, which then resolves and digests them correctly; every other stylesheet is processed unchanged. Bumped `config.assets.version` so host apps invalidate any stale cached skin asset. Added a regression spec covering the swap, the url expansion/digesting and that the icon font resolves.

- **Fix:** Restore `object_class` scoping on `CustomField#metas` and `CustomFieldGroup#metas`, [#1183](https://github.com/owen2345/camaleon-cms/pull/1183)
  - Regression introduced in #1173 (polymorphic meta ownership) dropped the `-> { where(object_class: 'CustomField' / 'CustomFieldGroup') }` scope from these associations. Meta rows are keyed by both `objectid` and `object_class`, so when a custom field's numeric id collided with another model's id (e.g. a `Post` sharing the same id), `get_option('field_key')` read the wrong `_default` meta and returned `nil`.
  - Visible symptom: on **General Site → Theme settings**, the `editor` Footer message field rendered as a plain `text_box` (no TinyMCE editor frame), because `_render.html.erb` fell back to `text_box` when `field_key` resolved to nil.
  - Restored the explicit scopes (matching 2.9.2 and the `CommonRelationships` convention) so each custom field/group only reads its own metas; added a model regression spec covering the colliding-id scenario.

- **Refactor:** Finalize Phase 6G runtime concern decomposition cleanup, [#1183](https://github.com/owen2345/camaleon-cms/pull/1183)
  - Finalizes concern-owned runtime wiring in `CamaleonController` while preserving helper delegate compatibility used by plugin/admin flows
  - Completes concern-focused spec/doc touch-ups for the split runtime and session-captcha concern boundaries
  - Code-review follow-ups: runtime concerns now `include` their corresponding helper modules instead of duplicating method bodies (single source of truth for `current_site`/`current_theme`, auth and email flows), `PluginRoutes.all_helpers` controller-side inclusion is restored, and back-compat ivars (`@current_site`, `@user`, `@_front_breadcrumb`, `@_hooks_skip`) are still assigned for templates/plugins while helpers themselves stay ivar-free
  - Helper ivar cleanup: the back-compat ivars are no longer set/read inside the shared view helpers (which Rails mixes into every view); they are now owned exclusively by the controller concerns (`RequestContextConcern#current_site`, `RuntimeHtmlContentConcern#theme_init`, `HookLifecycleConcern#hook_skip_list`, and `SessionRuntimeConcern` overrides of `login_user_with_password`/`cama_register_user`), so views are no longer polluted with controller ivars
  - Fix `NoMethodError (undefined method 'theme_asset')` raised when plugin/theme hooks (e.g. a theme's `on_install_theme`) run in controller context: `RuntimeShortcodeThemeConcern` now `include`s `CamaleonCms::ThemeHelper` (single source of truth) instead of duplicating only `theme_asset_path`/`theme_asset_url`/`theme_asset_file_path`, restoring the `theme_asset`/`theme_gem_asset` aliases plus `theme_view`/`theme_layout` on the controller runtime stack
  - Fix `NoMethodError (undefined method 'cama_captcha_tag')` raised when shortcodes/forms rendered in controller context (e.g. the contact-form plugin) call captcha rendering helpers: `SessionCaptchaRuntimeConcern` now `include`s `CamaleonCms::CaptchaHelper` (single source of truth) instead of re-implementing only the under-attack session counters, restoring `cama_captcha_tag`/`cama_captcha_build` on the controller runtime stack
  - Fix per-site theme view override (`app/apps/themes/<site_id>/views`) no longer being rendered: `FrontendController#configure_frontend_lookup_prefixes` again appends the `themes/<site_id>/views` lookup prefix (guarded by `Dir.exist?`) ahead of the active theme prefix, so site-specific overrides such as `home/_banner.html.erb` take precedence over the active theme's views
  - Fix 404s for legacy thumbnails: older Camaleon releases stored raster thumbnails as PNG regardless of the source extension (sample: `photo.jpg` => `thumb/photo-jpg.png`), but the thumb URL is derived from the source extension (`.jpg`). `CamaleonCmsLocalUploader#file_parse` now falls back to the legacy `.png` thumbnail when the computed thumb is missing on disk but a `.png` sibling exists (backwards-compatible: new uploads, PNG sources and S3 are unaffected)
  - Fix the same legacy-thumbnail 404s on the admin media browser (`/admin/media`): that list is served from cached `media` DB records (which still hold the `.jpg` thumb URL) and bypassed `file_parse`, so `CamaleonCmsLocalUploader#objects` now applies the same legacy `.png` fallback per cached image item before rendering
  - Fix 404s for image files that never get a thumbnail (sample: `.ico` favicons): such files are classified as images and given a `thumb/<name>` URL that does not exist on disk (the file lives one level above `/thumb`). `cama_compat_legacy_thumb` now falls back to the original file URL when neither the computed thumb nor a legacy `.png` sibling exists, so the admin media browser renders the original file instead of requesting a 404 thumb (backwards-compatible: files with real thumbnails are unaffected)
  - Fix `ActionView::MissingTemplate` raised when a plugin front controller renders one of its own templates (sample: `/store/plugins/<id>` => `render 'detail'`): the camaleon `LookupContext#find`/`#exists?` override (added in #1181) only merged the global `self.prefixes` when the explicit prefixes were blank, dropping the plugin's `init_plugin`-prepended `plugins/<name>/views/...` lookup prefix. The override now only restricts to the current theme (and skips the global merge) when the explicit prefixes are *entirely* theme-scoped; otherwise it merges `self.prefixes` as before, keeping theme-preview scoping intact while restoring plugin template lookups
  - Fix `NoMethodError (undefined method 'cama_content_append')` raised when plugin hooks running in controller context (e.g. `camaleon_post_order`'s `on_list_post` on the admin posts list) call the `cama_content_*` helpers: `RuntimeHtmlContentConcern` only duplicated `cama_content_init`, so the rest of the content surface was unreachable on the controller. It now `include`s `CamaleonCms::ContentHelper` (single source of truth) instead of duplicating `cama_content_init`/`cama_content_state`, restoring `cama_content_prepend`/`cama_content_append`/`cama_content_before_draw`/`cama_content_after_draw` on the controller runtime stack
  - Fix 404 for the `default` theme's Genericons webfont (sample: `/font/genericons-regular-webfont.eot`): the bundled `themes/default/assets/genericons/genericons.css` referenced the font files with relative `url('font/...')` paths, which the browser resolves against the page root (`/font/...`) when previewing/loading the theme. The three `@font-face` references (`.eot`/`.ttf`/`.svg`) now use the absolute asset-pipeline path (`/assets/themes/default/assets/genericons/font/...`) so they resolve regardless of the page URL (this was a long-standing issue in the vendored CSS, not introduced by the refactor)
  - Fix `NoMethodError (undefined method 'to_sym' for nil)` raised when editing a custom field group (`/admin/settings/custom_fields/<id>/edit`) that contains a legacy/orphaned field whose stored options lost their `field_key` (sample options: `{ not_deleted: true }`): `_get_items.html.erb` called `@key.to_sym` unconditionally. It now guards against a blank `@key` (`@field_config` becomes nil and the existing `unless @field_config.nil?` skips that field), so the form renders instead of crashing (long-standing data-robustness issue, not introduced by the refactor; backwards-compatible: fields with a valid `field_key` render unchanged)
  - Fix `Sprockets::Rails::Helper::AssetNotPrecompiledError` for plugin/theme assets (sample: editing a post raised it for `plugins/visibility_post/assets/js/form.js` when the Sprockets manifest cache was cold/incomplete): on Sprockets >= 4 (with `unknown_asset_fallback` disabled) the gem's precompile declaration was gated to Sprockets 3 only (`!Sprockets.const_defined?(:BabelProcessor)`) and used a `proc`/glob, so on Sprockets 4 plugin/theme assets were not reliably declared as precompiled. The new `CamaleonCms::AssetsPrecompile.logical_paths` enumerates the concrete plugin/theme asset files from the real Sprockets load paths (`config.assets.paths`, with the host and gem `app/apps` as a fallback) and declares their exact logical paths in `config.assets.precompile` as plain strings — the canonical, Sprockets-version-agnostic form (works on 3.x and 4.x). Scanning the actual asset roots (and the full `plugins/`/`themes/` subtrees, excluding partials, views and non-assets) covers host, gem-bundled (e.g. `visibility_post`) and separately gem-packaged `gem_mode` plugins/themes (e.g. `plugins/cama_contact_form/admin_editor.js`), matching the reach of the old `proc`. Because the list is derived from the on-disk files, every installed plugin/theme is declared whether or not it is currently active, so switching themes / enabling-disabling plugins (DB-only operations) never needs a recompile (long-standing Sprockets-4 incompatibility, not introduced by the refactor; backwards-compatible)
  - Fix frontend posts/taxonomies with localized (multi-language) slugs returning 404 (sample: a post whose slug is stored as `<!--:en-->sample-post<!--:--><!--:ru-->sample-post<!--:-->` not found at `/sample-post`): several lookups had been changed from the multi-language-aware `find_by_slug` (which matches both the plain slug and the `%-->slug<!--%` localized form) to `find_by(slug:)`, which only matches the raw stored value and never the per-locale slug. Restored `find_by_slug` at every affected slug lookup (`FrontendController` post/post_type/post_tag/category, `SiteDecorator#the_post`/`the_category`/`the_tag`/`the_post_type`, `PostTypeDecorator`/`CategoryDecorator`/`TermTaxonomyDecorator`, `Site#get_valid_post_slug`, `PostType#default_category`, `NavMenusController`, `NavMenuHelper`, `ShortCodeHelper`, `RuntimeShortcodeThemeConcern`, `front_cache` plugin, and one feature spec), restoring 2.9.2 behavior (backwards-compatible: plain slugs still match). Each call carries an inline `# rubocop:disable Rails/DynamicFindBy` (instead of a project-wide `.rubocop.yml` allowance) to keep the intentional use visible and prevent accidental "fixes" back to `find_by(slug:)`. The remaining slug lookups in `CustomFieldGroup#get_field`/`auto_save_default_values` and `CustomFieldsRead#add_custom_field_group`/`add_custom_field_to_default_group` were also switched to `find_by_slug` for consistency (behavior unchanged for plain custom-field slugs; for `Post` owners it additionally becomes multi-language aware). Added an organic, behavioural guard spec (`spec/find_by_slug_usage_spec.rb`) that exercises every `find_by_slug` call site against real records (no source-code scanning): the `posts`-backed call sites (`SiteDecorator#the_post`, `TermTaxonomyDecorator#the_post`, `Site#get_valid_post_slug`, `FrontendController#render_post`, and the `the_posts.find_by_slug` relation behind the `front_cache` plugin) are tested with a post stored under a localized slug, so they genuinely fail if reverted to `find_by(slug:)` (verified via mutation); the remaining term_taxonomy/custom-field call sites are covered with real-record behavioural tests for the uniform convention (they resolve to Rails dynamic finder, functionally identical to `find_by(slug:)`)

- **Fix & Refactor:** Phase 5 — Restore theme preview rendering and refactor nav-menu-helper, [#1181](https://github.com/owen2345/camaleon-cms/pull/1181)
  - Part 1: Restore preview rendering
    - Fixes preview theme state override: prefer `@_current_theme` ivar over cached site theme
    - Fixes legacy template ivar support: set `@current_site` on all `current_site` paths
    - Fixes preview hook dispatch: use preview theme slug instead of site theme slug
    - Adds preview menu bootstrap: scans theme templates for nav_menu references and auto-creates missing menus
    - Resolves broken preview rendering for `cv` and `e_shop` themes
  - Part 2: Refactor nav-menu-helper (planned)
    - Replace breadcrumb and visited-state ivars with request-scoped CurrentRequest state
    - Add comprehensive helper specs for breadcrumb and active-item detection
    - Remove final `Rails/HelperInstanceVariable` exclusion for frontend/nav_menu_helper.rb

- **Refactor:** Replace Phase 4 session/shortcode/comment helper instance-variable state, [#1179](https://github.com/owen2345/camaleon-cms/pull/1179)
  - Refactors `session_helper`, `short_code_helper`, and `comment_helper` to avoid helper ivar state via request-scoped `CurrentRequest` and explicit context passing
  - Preserves controller/view compatibility points used by existing admin/session/shortcode flows
  - Removes Phase 4 helper exclusions from `Rails/HelperInstanceVariable` in `.rubocop_todo.yml`
  - Adds helper coverage for session and comment helpers and keeps shortcode helper coverage in place

- **Refactor:** Replace Phase 3 admin/menu/taxonomy helper instance-variable state with CurrentRequest-backed state, [#1178](https://github.com/owen2345/camaleon-cms/pull/1178)
  - Refactors admin menus, post type, and custom fields helpers to use request-scoped CurrentRequest state
  - Eliminates traversal stack and registry instance variables from admin/menus, taxonomy hierarchy, and custom field helpers
  - Removes unused `cama_requestAction` method from camaleon_helper
  - Keeps legacy taxonomy-list compatibility for call sites that omit `post_type`
  - Adds comprehensive helper specs for menu management, hierarchy building, and field registry lifecycle, split per helper module

- **Refactor:** Replace Phase 2 frontend helper context with CurrentRequest-backed state, [#1177](https://github.com/owen2345/camaleon-cms/pull/1177)
  - Refactors frontend content, SEO, and site helpers to use request-scoped CurrentRequest state
  - Preserves frontend object/block context, current path, current theme, and visited-state fallback behavior
  - Adds helper specs for the frontend application helper stack

- **Refactor:** Replace Phase 1 helper instance-variable state with CurrentRequest-backed state, [#1176](https://github.com/owen2345/camaleon-cms/pull/1176)
  - Refactors content, hooks, html, and theme helpers to use request-scoped CurrentRequest state
  - Extends CurrentRequest with helper state attributes used by these helpers
  - Adds helper specs for content/hooks/theme state lifecycle and html helper state behavior

- **Fix:** Restore admin preview locale compatibility for decorators and plugin helpers, [#1175](https://github.com/owen2345/camaleon-cms/pull/1175)
  - Restores the admin-side frontend locale compatibility path removed by #1166
  - Preserves theme previews and other admin-rendered frontend flows that rely on frontend URLs or plugin helpers such as `camaleon-ecommerce`

- **Security fix:** Fix Rails OutputSafety sinks while preserving menu and asset rendering, [#1174](https://github.com/owen2345/camaleon-cms/pull/1174)
  - Escapes untrusted HTML in attack responses, media crop output, edit-link labels, hierarchy titles, and select option generation
  - Keeps trusted cached markup replay and asset injection paths explicit and narrowly suppressed
  - Restores trusted frontend/admin menu HTML and renderable asset tags after the output-safety cleanup

- **Refactor:** Implement native Rails STI for term taxonomies and posts, and add polymorphic meta ownership, [#1173](https://github.com/owen2345/camaleon-cms/pull/1173)
  - Moves `TermTaxonomy` and `PostDefault` onto native STI so subclasses resolve through Rails instead of custom taxonomy plumbing
  - Introduces polymorphic `owner` associations for metas and custom-field records to simplify shared association setup
  - Updates related models and specs to match the new inheritance and ownership behavior

- **Style & tooling:** Add RuboCop plugin gems and fix all offenses, [#1167](https://github.com/owen2345/camaleon-cms/pull/1167)
  - Added `rubocop-performance`, `rubocop-rails`, `rubocop-capybara`, `rubocop-factory_bot`, `rubocop-rake`, `rubocop-rspec_rails` to development dependencies
  - Fixed hundreds of Layout, Style, Performance, and Rails offenses across 92 files
  - Set maximum line length to 120; reformatted codebase to comply

- **Style & testability:** Refactor HTML in Ruby code to Rails tags [#1172](https://github.com/owen2345/camaleon-cms/pull/1172)
  - Replaced raw HTML string concatenation with Rails helpers (`content_tag`, `tag`, `image_tag`, `link_to`, `safe_join`, `StringScanner`) across 12 files
  - Helpers refactored: `nav_menu_helper`, `html_helper`, `short_code_helper`, `captcha_helper`, `menus_helper`, `admin_controller`
  - Plugins refactored: `authoring_post_helper`, `visibility_post_helper`
  - Models: use `ActionController::Base.helpers` for default site content generation in `site_default_settings`; fix nil-handling in `fix_post_order`
  - Added FactoryBot factories for `nav_menu` and `nav_menu_item`
  - Added full specs for captcha helper, nav menu helper, and post `fix_post_order`

- **Security fix:** Fix two unprotected redirects via `params[:return_to]` in `sessions_controller.rb` and `session_helper.rb` [#1168](https://github.com/owen2345/camaleon-cms/pull/1168)
  - Both used `params[:return_to]` directly in `redirect_to`, allowing open redirect attacks
  - Fixed by routing through the existing `safe_redirect_url` helper
  - Added tests in `spec/requests/security/open_redirect_session_spec.rb`
- **Security, style, and cleanup:** Rubocop fixes part 1 [#1168](https://github.com/owen2345/camaleon-cms/pull/1168)
  - Fixed `Style/IfUnlessModifier`, `Rails/Output`, `Rails/FilePath`, `Performance/InefficientHashSearch`, `Performance/RedundantMerge`, `Performance/StringReplacement`, `Rails/Presence`, `RSpecRails/HttpStatus`, `Rails/DynamicFindBy`, `Rails/FindEach`, `Rails/SkipsModelValidations`, `Rails/Time`, `Rails/Date`, `Rails/ApplicationRecord`, `Rails/Blank`
  - Removed dead code: `cama_draw_timer`, `all_locales_for_routes`, `cama_get_options_html_from_items`, `cama_parse_for_thumb_name`
  - Set `TargetRailsVersion` to `6.1` in `.rubocop.yml`

- **Security fix:** Bump gems — Nokogiri to 1.19.3, action_text-trix, aws-sdk, puma, rubyzip, selenium-webdriver, sqlite3, Bundler 2.7.2 [#1170](https://github.com/owen2345/camaleon-cms/pull/1170)

- **Fix:** Decorator locale resolution and language context mixing (fixes issue #233), [#1166](https://github.com/owen2345/camaleon-cms/pull/1166)
  - **Phase 1:** Fix locale accessibility and language context mixing
    - Move `cama_get_i18n_frontend` helper to parent CamaleonController so both frontend and admin decorators can access correct locale
    - Move `@cama_i18n_frontend` initialization to FrontendController.init_frontent (after language switching logic)
    - Fix AdminSessionsController to NOT read frontend's `session[:cama_current_language]` (prevents breadcrumb showing wrong language when switching frontend→admin)
  - **Phase 2:** Simplify to rely on I18n.locale alone
    - Remove redundant `@cama_i18n_frontend` instance variable (it just mirrored I18n.locale)
    - Simplify decorator priority chain to 3 levels: explicit > @_deco_locale > I18n.locale
    - Cleaner code: removed try-rescue overhead, direct I18n.locale fallback
  - Result: Decorators now correctly use site's frontend language in frontend context, admin language in admin context
  - Add 8 comprehensive locale resolution tests

- **Bug fix:** Fix thread-safety issues with `PluginRoutes.reload` causing persistent 500 errors, [#1163](https://github.com/owen2345/camaleon-cms/pull/1163)
  - Remove unnecessary `PluginRoutes.reload` from `plugins#index` and `themes#index` actions
  - Refactor class variables (`@@`) to class instance variables (`@`) with `Monitor` for thread-safe route reloading and cache access
  - Fix `return` in blocks by using `find` instead of `each`
  - Add 27 tests for `PluginRoutes`, `plugins`, and `themes` controllers

- **Optimize PluginRoutes.draw_gems and apps_dir methods** Micro-optimizations for memory consumption and performance, [#1164](https://github.com/owen2345/camaleon-cms/pull/1164)

## [2.9.2](https://github.com/owen2345/camaleon-cms/tree/2.9.2) (2026-05-01)

**This release is fixing several security vulnerabilities! Please, upgrade ASAP!**

- **BREAKING CHANGE - Security fix:** Fix Broken Access Control (CWE-862) in MediaController, [#1147](https://github.com/owen2345/camaleon-cms/pull/1147)
  - Add consistent authorization checks to all MediaController endpoints requiring `:manage, :media` permission
  - Previously, only `index` and `ajax` actions checked authorization; other endpoints (`upload`, `download_private_file`, `crop`, `actions`) only checked authentication
  - All endpoints now protected by centralized `before_action :verify_media_authorization`
  - Thanks, Seoyoung Kang for reporting this
- **BREAKING CHANGE - Security fix:** Centralize plugin admin authorization in `PluginsAdminController`, [#1142](https://github.com/owen2345/camaleon-cms/pull/1142)
  - All plugin admin routes now require `manage :plugins` permission by default (fail-closed)
  - `/admin/plugins/*/settings` and related endpoints protected without per-controller opt-in
  - Third-party plugins (via Ruby gems like `cama_contact_form`, `cama_meta_tag`) automatically protected when inheriting from `PluginsAdminController`
  - Thanks, Amir Aliu and Enrik Mustafa for reporting this
- **BREAKING CHANGE - Security fix:** Restrict `select_eval` custom field type to authorized users only, [#1136](https://github.com/owen2345/camaleon-cms/pull/1136)
  - The `select_eval` field type can execute arbitrary Ruby code and now requires explicit permission
  - Added `select_eval` permission to User Roles UI (appears as "Select Eval" checkbox under Manager Permissions)
  - Users with 'admin' role automatically have full access (via `can :manage, :all`)
  - Non-admin users must be explicitly granted `select_eval: 1` permission in their role meta
  - Implemented `CurrentRequest` (ActiveSupport::CurrentAttributes) for thread-safe, request-scoped access to `current_user` and `current_site`
  - Added authorization checks at model layer: `CustomFieldGroup#add_field`, `CustomFieldGroup#add_fields`, and `CustomField` before_update callback
  - **Migration required:** See [docs/MIGRATION_SELECT_EVAL.md](docs/MIGRATION_SELECT_EVAL.md) for detailed upgrade instructions
  - **Security documentation:** See [Permissions & Security Guide](docs/security/permissions.md)
  - Run `bundle exec rake camaleon_cms:backfill_select_eval_permission` to fix the permission checkbox on admin roles
    - Thanks, Ik0nw, Thomas Wells, Amir Aliu & Enrik Mustafa, and l1nk for reporting this 
- **BREAKING CHANGE** - Add permissions for Custom Fields management in the admin area, [#1134](https://github.com/owen2345/camaleon-cms/pull/1134)
  - Existing installs upgrading to 2.9.2 should review the [migration guide](docs/upgrading-to-2.9.2.md)

- **Security fix:** Fix Brakeman vulnerabilities: dangerous eval in plugin_routes, path traversal in MediaController, and SQL injection in visibility_post_helper, [#1160](https://github.com/owen2345/camaleon-cms/pull/1160)
- **Security fix:** Fix Brakeman XSS vulnerabilities, [#1159](https://github.com/owen2345/camaleon-cms/pull/1159)
- **Security fix:** Fix mass assignment vulnerabilities in Categories, Widgets, Posts, Users, and other admin controllers, [#1158](https://github.com/owen2345/camaleon-cms/pull/1158)
- **Security fix:** Fix mass assignment vulnerabilities in NavMenusController, [#1157](https://github.com/owen2345/camaleon-cms/pull/1157)
- **Security fix:** Fix open redirect vulnerability in session helper via return_to cookie, [#1155](https://github.com/owen2345/camaleon-cms/pull/1155)
- **Security fix:** Fix reflected XSS vulnerability via `params[:info]` in flash messages, [#1154](https://github.com/owen2345/camaleon-cms/pull/1154)
- **Security fix:** Fix mass assignment and open redirect vulnerabilities in SitesController, [#1152](https://github.com/owen2345/camaleon-cms/pull/1152)
  - Replace `permit!` with strong `site_params` allowing only `:name`, `:slug`, `:description`
  - Redirect to `cama_admin_path` instead of `@site.the_admin_url` to prevent open redirect
- **Security fix:** Fix Stored XSS (CWE-79) in the_content helper, [#1149](https://github.com/owen2345/camaleon-cms/pull/1149)
  - The `the_content` helper was using `.html_safe` which bypassed Rails' XSS protection
  - Changed to use `sanitize()` which uses Rails' allowlist approach
  - Thanks, Pratik Karan for reporting this
- **Security fix:** Fix IDOR (CWE-639) in CategoriesController, [#1148](https://github.com/owen2345/camaleon-cms/pull/1148)
  - Users with category management permission for one Post Type could modify/delete categories from other Post Types by manipulating request parameters
  - Changed `set_category` to scope lookup to authorized `@post_type` instead of global lookup
  - Thanks, Seoyoung Kang for reporting this
- **Security fix:** Fix SSTI (Server-Side Template Injection) in test_email endpoint, [#1145](https://github.com/owen2345/camaleon-cms/pull/1145)
  - Replace `render inline:` with `render plain:` to prevent ERB evaluation of exception messages
  - This prevents authenticated admins from potentially executing arbitrary code via crafted error messages
  - Thanks, Amir Aliu and Enrik Mustafa for reporting this
- **Security fix:** Fix SQL Injection in `PostUniqValidator` (authenticated, boolean-based blind SQLi via post slug), [#1144](https://github.com/owen2345/camaleon-cms/pull/1144)
  - Use parameterized queries instead of string interpolation for slug validation
  - Thanks, Amir Aliu and Enrik Mustafa for reporting this
- **Security fix:** Fix Stored XSS in post title rendering, [#1143](https://github.com/owen2345/camaleon-cms/pull/1143)
  - Add HTML escaping to post titles when displayed in admin views (e.g., drafts list)
  - Thanks, Amir Aliu and Enrik Mustafa for reporting this
- **Security fix:** Upgrade development Rails to 8.1.3 and other gems, [#1141](https://github.com/owen2345/camaleon-cms/pull/1141)
- **Security fix:** Fix mass assignment vulnerability in user registration (cross-tenant account injection), [#1140](https://github.com/owen2345/camaleon-cms/pull/1140)
  - Replace `permit!` with explicit whitelist of allowed params in `SessionsController#user_permit_data`
  - Remove `params[:meta]` from user registration to prevent arbitrary meta injection
  - Thanks, Aryan Bhagat for reporting this
- **Security fix:** Add authorization checks for broken access control, [#1139](https://github.com/owen2345/camaleon-cms/pull/1139)
  - Thanks, Amir Aliu & Enrik Mustafa for reporting this 
- **Security fix:** Fix SSRF vulnerability in media URL upload, [#1133](https://github.com/owen2345/camaleon-cms/pull/1133)
  - Thanks, Minjun Lee for reporting this 
- **Security fix:** Bump `json`, `action_text-trix`, `bcrypt`, `loofah` to fix vulnerabilities, [#1132](https://github.com/owen2345/camaleon-cms/pull/1132)
- **Security fix:** Fix RCE in custom-field i18n rendering, [#1129](https://github.com/owen2345/camaleon-cms/pull/1129)
  - Thanks, Nguyen Trung Kien and Mohammad KH Yaseen for reporting this 
- **Security fix:** Fix path traversal in `CamaleonCmsAwsUploader`, [#1127](https://github.com/owen2345/camaleon-cms/pull/1127)
  - Thanks, William chengw625@gmail.com, Michael Loomis (@investigato), and Wade Sparks III from VulnCheck for reporting this 



- Add Brakeman and bundle-audit to CI, [#1161](https://github.com/owen2345/camaleon-cms/pull/1161)
- CI: Update `actions/checkout` to v6, [#1156](https://github.com/owen2345/camaleon-cms/pull/1156)
- CI: Use binstubs in CI, [#1151](https://github.com/owen2345/camaleon-cms/pull/1151)
- Security: Add `brakeman` and `bundle-audit` gems to development/test groups, [#1150](https://github.com/owen2345/camaleon-cms/pull/1150)
- Docs: Harden `AGENTS.md` to enforce agent workflow, [#1146](https://github.com/owen2345/camaleon-cms/pull/1146)
- Docs: Add `AGENTS.md` and AI agent documentation in `docs/ai/` for agent behavior, Rails/RSpec conventions, and project guidance, [#1138](https://github.com/owen2345/camaleon-cms/pull/1138)
- Fix: rewind Tempfile after scanning to avoid 0-byte uploads (regression fixed; tests added), [#1137](https://github.com/owen2345/camaleon-cms/pull/1137)
  - Thanks, Minjun Lee for reporting this
- Fix: Apply Rubocop style fixes, [#1131](https://github.com/owen2345/camaleon-cms/pull/1131)
- Dependencies: Bump `flatted` from 3.2.7 to 3.4.2, [#1130](https://github.com/owen2345/camaleon-cms/pull/1130)
- Fix: Add migration safe-guards and modernize migration code, [#1128](https://github.com/owen2345/camaleon-cms/pull/1128)
- Dependencies: Bump `minimatch` from 3.1.2 to 3.1.5, [#1126](https://github.com/owen2345/camaleon-cms/pull/1126)
- CI: Modernize CI, remove EOL Ruby/Rails versions, [#1125](https://github.com/owen2345/camaleon-cms/pull/1125)
- Dependencies: Bump `cross-spawn` from 7.0.3 to 7.0.6, [#1122](https://github.com/owen2345/camaleon-cms/pull/1122)
- Fix: Normalize widget behavior, [#1120](https://github.com/owen2345/camaleon-cms/pull/1120)
- Fix: Replace deprecated `JSON.fast_generate` with `generate`, [#1116](https://github.com/owen2345/camaleon-cms/pull/1116)

# [2.9.1](https://github.com/owen2345/camaleon-cms/tree/2.9.1) (2025-03-15)

**This release is fixing several security vulnerabilities! Please, upgrade ASAP!**

- **Security fix:** Mitigate a Privilege Escalation through a Mass Assignment, [fixing the `updated_ajax` action of admin 
UsersController to permit only legit params](https://github.com/owen2345/camaleon-cms/pull/1109)
  - Thanks Joshua Martinelle from Tenable cybersecurity company for reporting this
- **Security fix:** 
[Sanitize fields, comments, and metas against xss attacks](https://github.com/owen2345/camaleon-cms/pull/1113)
  - Thanks [glno815](https://github.com/glno815) for [reporting this](https://github.com/owen2345/camaleon-cms/issues/1103)
- Removed Gemfile.lock from .gitignore - [as recommended](https://github.com/owen2345/camaleon-cms/pull/1108)
- Fix requiring logger, because concurrent-ruby isn't doing this anymore
- [Avoid CI jobs duplication](https://github.com/owen2345/camaleon-cms/pull/1112)
- Restrict Chromedriver to 124.x version and selenium-webdriver to 4.23.0 to avoid test failures
  - Selenium isn't keeping pace with Chromes development of the Webdriver BiDi protocol, so several tests were 
intermittently failing, and with Chromedriver 134.x it became totally unusable. Let's wait for future fixes


# [2.9.0](https://github.com/owen2345/camaleon-cms/tree/2.9.0) (2025-01-06)
- Fix false positive on malicious upload check
- Add magic comment to silence Ruby 3.4 deprecation warnings
- **Feature:** Support custom aws endpoint
  -  Thanks [Grayson Chen](https://github.com/graysonchen) for crafting a PR adding this feature

# [2.8.3](https://github.com/owen2345/camaleon-cms/tree/2.8.3) (2024-09-16)

- Remove unused underscore.js
- Bump IntroJS to 7.2.0
- Upgrade jquery-validate to 1.21.0
  - Add messages for Arabic language
  - Add `methods_ln.js` files with regexps for DE, NL, and PT languages
  - Modify admin layout view to load the `methods_ln.js` file with a `javascript_include_tag` if the file exists
- Fix uploads to AWS S3 folders
  - Also, introduced the path traversal validation to the add_folder method, which was found unsafe

## [2.8.2](https://github.com/owen2345/camaleon-cms/tree/2.8.2) (2024-08-25)

- Bump AdminLTE to 2.3.11
  - Has several CSS fixes and doesn't yet require jQuery 3.x
- Fix `TermTaxonomy` attributes sanitizing to not remove translation tags in [\#1091] (https://github.com/owen2345/camaleon-cms/pull/1091)
- Add bootstrap.min.css.map
  - Works OK in the development environment if the `config.assets.debug = true` is set.

## [2.8.1](https://github.com/owen2345/camaleon-cms/tree/2.8.1) (2024-08-21)

**This release is fixing several security vulnerabilities! Please, upgrade ASAP!**

- Replace sass-rails with dartsass-sprockets
  - Remove `sass` and `sass-rails` gems from the main app's Gemfile when upgrading `camaleon_cms` to this version
- Fix colorpicker missing admin asset, adding it to `admin-manifest.css`
- **Security fix:** Mitigate arbitrary path write in uploader (GHSL-2024-182)
  - Thanks [Peter Stöckli](https://github.com/p-) for reporting and providing clear reproduction steps
- Add Rails 7.2 to stable testing on CI, point rails_edge to main branch
- **Security fix:** Mitigate arbitrary path traversal in download_private_file (GHSL-2024-183)
  - Thanks [Peter Stöckli](https://github.com/p-) for reporting and providing clear reproduction steps
- **Security fix:** Mitigate stored XSS through user file upload (GHSL-2024-184)
  - Thanks [Peter Stöckli](https://github.com/p-) for reporting and providing clear reproduction steps
- **Security fix:** Mitigate remote code execution through code injection (GHSL-2024-185)
  - Thanks [Peter Stöckli](https://github.com/p-) for reporting and providing clear reproduction steps
- **Security fix:** Mitigate arbitrary file delete vulnerability (GHSL-2024-186)
  - Thanks [Peter Stöckli](https://github.com/p-) for reporting and providing clear reproduction steps
- Use actions/checkout@v4 on CI to remove warning about deprecated Node JS version

## [2.8.0](https://github.com/owen2345/camaleon-cms/tree/2.8.0) (2024-07-26)
- Use jQuery 2.x - 2.2.4
  - **If there are `//= require jquery` clauses in the main application, replace them with `//= require jquery2`**
- Add Ruby 3.3 and Rails 7.2 to CI
- Replace Tuzitio links with `camaleon.website` and `http` with `https`
- On cama_site_check_existence, if site is unknown, use `allow_other_host: true` for redirection to main site
  - Starting from Rails 7.0 a redirection to other host will raise an exception unless the `redirect_to` method is
    called with the `allow_other_host: true` option
- Set sprocket-rails version to be at least 3.5.1
- Use MiniMime for mime types, because the MiniMagick 5.0 has no Image#mime_type
- Reimplement the temporary uploaded file removing, wrapping it in a bl…ock to make possible overriding the block in the app initializer to use an async job
- Sanitize name and description attrs of TermTaxonomy classes to prevent XSS attacks
- **Potentially breaking change:** Fix ActiveRecord deprecations from Rails 6.1
  - `fields`, `field_values`, and `field_groups` associations have been removed from the CustomFieldsRead mixin module
  - `custom_fields`, `custom_field_values`, and `custom_field_groups` associations should be used instead
  - Beware that the CustomFieldsRead mixin is included into the TermTaxonomy base model, PostDefault model, and UserMethods mixin

## [2.7.5](https://github.com/owen2345/camaleon-cms/tree/2.7.5) (2023-11-22)
- Fix the test email for non-main sites by [brian-kephart](https://github.com/brian-kephart) in [\#1050](https://github.com/owen2345/camaleon-cms/pull/1050)
- Bump semver from 7.3.8 to 7.5.3 by [dependabot](https://github.com/apps/dependabot) in [\#1057](https://github.com/owen2345/camaleon-cms/pull/1057)
- UserUrlValidator for SSRF mitigation by [texpert](https://github.com/texpert) in [\#1048](https://github.com/owen2345/camaleon-cms/pull/1048)
  - Thanks [paragbagul111](https://github.com/paragbagul111) for reporting the issue
- Bump word-wrap from 1.2.3 to 1.2.4 by [dependabot](https://github.com/apps/dependabot)  in [\#1059](https://github.com/owen2345/camaleon-cms/pull/1059)
- Remove webdrivers gem, which has no support for Chrome v115 [texpert](https://github.com/texpert) in [\#1060](https://github.com/owen2345/camaleon-cms/pull/1060)
- Fix JS after conversion from CoffeeScript [texpert](https://github.com/texpert) in [\#1062](https://github.com/owen2345/camaleon-cms/pull/1062)

## [2.7.4](https://github.com/owen2345/camaleon-cms/tree/2.7.4) (2023-04-11)
- Sanitize error messages when rendering them directly from the controller

## [2.7.3](https://github.com/owen2345/camaleon-cms/tree/2.7.3) (2023-04-07)
- Inclusion of CommonRelationships into subclasses is now performed in an inherited hook

## [2.7.2](https://github.com/owen2345/camaleon-cms/tree/2.7.2) (2023-03-24)
- Fix bug rendering category pages

## [2.7.1](https://github.com/owen2345/camaleon-cms/tree/2.7.1) (2023-03-22)
- Fix common relationships

## [2.7.0](https://github.com/owen2345/camaleon-cms/tree/2.7.0) (2023-03-22)
- Change some render calls from `inline` to `plain`
- Stop monkeypatching ActiveRecord::Base
  - Use CamaleonRecord, not ApplicationRecord, as a base class for the models
- Fix canonical URLs for translated sites
- Lint Ruby using RuboCop
- Lint JS using ESLint
- Use cama_contact_form v. 0.1.0
- Migrate CoffeeScript files to JS
- Do not redundantly compile default theme assets
- Remove temporary dependencies
- Add Ruby 3.2 to CI
- Require Rails 6+
- Require Ruby 2.7+

## [2.6.4](https://github.com/owen2345/camaleon-cms/tree/2.6.4) (2022-06-08)
- Reformat JSON comments for OJ compatibility
- Use OJ in testing
- Test for asset existence when running spec
- Fix some typos

## [2.6.3](https://github.com/owen2345/camaleon-cms/tree/2.6.3) (2022-03-11)
- Move glyphicons to correct folder

## [2.6.2](https://github.com/owen2345/camaleon-cms/tree/2.6.2) (2022-02-21)
- Fix TinyMCE icons
- Update welcome post
- Make sure built-in theme assets get compiled

## [2.6.1](https://github.com/owen2345/camaleon-cms/tree/2.6.1) (2021-12-7)
- Ruby 3.1 support
- Rails 7.0 support
- Require Ruby 2.6+
- Require Rails 5.2+

## [2.6.0.1](https://github.com/owen2345/camaleon-cms/tree/2.6.0.1) (2021-10-12)
- Fix comment injection vulnerability
- Fix DoS vulnerability when uploading empty SVG
- Log out user when admin changes their password
- Disallow uploading from local URLs to prevent SSRF

## [2.6.0](https://github.com/owen2345/camaleon-cms/tree/2.6.0) (2021-01-27)
- Add Moldavian language
- Separate locales in files per folders/namespaces
- Add unfilled strings to English locale
- Rails 6.1 support

## [2.5.3.1](https://github.com/owen2345/camaleon-cms/tree/2.5.3.1) (2020-08-04)
- Use non-digest-assets gem for using 3rd party assets (fix missing not found glyphicon fonts)

## [2.5.3](https://github.com/owen2345/camaleon-cms/tree/2.5.3) (2020-07-02)
- Russian locale additions and fixes
- Fix deprecation warnings present in Ruby 2.7 and Rails 6.0
- Fix admin error path
- Process shortcodes when evaluating widgets
- Add canonical option to seo
- Theme template include i18n
- Upgrade Bootstrap from 3.3.4 to 3.4.1

## [2.5.0](https://github.com/owen2345/camaleon-cms/tree/2.5.0) (2020-01-08)
- feat: sprockets 4 support
- feat: for sprockets 4, generate config manifest to precompile
- feat: precompile assets only for sprockets <= 3x
- fix: Rails 6 missing to_s for session id
- fix: preview error

## [2.4.6.7](https://github.com/owen2345/camaleon-cms/tree/2.4.6.7) (2019-08-05)
- Fixed rails 6 bundle install error
- Added https to default uri options
- Use default page if no other pages exist

## [2.4.6.4](https://github.com/owen2345/camaleon-cms/tree/2.4.6.6) (2019-08-05)
- Fixed posts slug index length
- Added support for rails 6
- Improved themes list UI

## [2.4.6.4](https://github.com/owen2345/camaleon-cms/tree/2.4.6.1) (2019-05-02)
- Updated aws-sdk dependency to include only s3 needed dependency available in aws-sdk v3+

## [2.4.6.3](https://github.com/owen2345/camaleon-cms/tree/2.4.6.1) (2019-05-02)
- Fixed cache plugin to support several domains/hosts

## [2.4.6.2](https://github.com/owen2345/camaleon-cms/tree/2.4.6.1) (2019-05-02)
- Fixed route errors for error for non static error pages

## [2.4.6.1](https://github.com/owen2345/camaleon-cms/tree/2.4.6.0) (2019-04-16)
- Fixed s3 nil error

## [2.4.6.0](https://github.com/owen2345/camaleon-cms/tree/2.4.6.0) (2019-04-05)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.14...2.4.6.0)

- Cannot create site on Rails 6 [\#884](https://github.com/owen2345/camaleon-cms/issues/884)
- Loosen CanCanCan version restriction [\#886](https://github.com/owen2345/camaleon-cms/pull/886) ([brian-kephart](https://github.com/brian-kephart))
- Set config.belongs\_to\_required\_by\_default = false for Rails 6 [\#885](https://github.com/owen2345/camaleon-cms/pull/885) ([brian-kephart](https://github.com/brian-kephart))
- Use implicit return on case statement assignment [\#858](https://github.com/owen2345/camaleon-cms/pull/858) ([chukitow](https://github.com/chukitow))
- Fixed update posts to exclude slug verification in trash posts
- Updated min version of contact form plugin

## [2.4.5.14](https://github.com/owen2345/camaleon-cms/tree/2.4.5.14) (2019-03-24)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.13...2.4.5.14)

**Closed issues:**

- Issue in production mode [\#882](https://github.com/owen2345/camaleon-cms/issues/882)
- Missing template themes/\[themename\]/views/single [\#875](https://github.com/owen2345/camaleon-cms/issues/875)

**Merged pull requests:**

- Use headless Chrome instead of Capybara-Webkit [\#881](https://github.com/owen2345/camaleon-cms/pull/881) ([brian-kephart](https://github.com/brian-kephart))
- apply fix in \#878 when site has a custom error page [\#880](https://github.com/owen2345/camaleon-cms/pull/880) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.5.13](https://github.com/owen2345/camaleon-cms/tree/2.4.5.13) (2019-03-11)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.12...2.4.5.13)

**Closed issues:**

- Contact form throws error on submission [\#877](https://github.com/owen2345/camaleon-cms/issues/877)
- "the\_avatar" showing as undefined. [\#874](https://github.com/owen2345/camaleon-cms/issues/874)
- PG::UndefinedFunction: ERROR: function lower\(boolean\) when searching in admin panel [\#866](https://github.com/owen2345/camaleon-cms/issues/866)
- SEO field is not saving for specific custom group [\#863](https://github.com/owen2345/camaleon-cms/issues/863)
- module CamaleonCms::UploaderHelper - north\_east north\_west params [\#860](https://github.com/owen2345/camaleon-cms/issues/860)
- Camaleon CMS in Rails 5, adding a new post the form disappear when updating the category [\#859](https://github.com/owen2345/camaleon-cms/issues/859)
- Intro Popups in the Admin Screen [\#781](https://github.com/owen2345/camaleon-cms/issues/781)

**Merged pull requests:**

- Restrict sqlite3 version due to Rails incompatibility [\#879](https://github.com/owen2345/camaleon-cms/pull/879) ([brian-kephart](https://github.com/brian-kephart))
- Fix 500 errors when missing theme CSS is requested [\#878](https://github.com/owen2345/camaleon-cms/pull/878) ([brian-kephart](https://github.com/brian-kephart))
- Revert "fixed S3 bucket options merge error" [\#873](https://github.com/owen2345/camaleon-cms/pull/873) ([owen2345](https://github.com/owen2345))
- fixed S3 bucket options merge error [\#872](https://github.com/owen2345/camaleon-cms/pull/872) ([superchell](https://github.com/superchell))
- changed aws-sdk dependency version for ActiveStorage support [\#870](https://github.com/owen2345/camaleon-cms/pull/870) ([superchell](https://github.com/superchell))
- Fix query builder bug when params\[:q\] specified [\#868](https://github.com/owen2345/camaleon-cms/pull/868) ([blaszczakphoto](https://github.com/blaszczakphoto))
- fixed url in hreflang link [\#831](https://github.com/owen2345/camaleon-cms/pull/831) ([superchell](https://github.com/superchell))

## [2.4.5.12](https://github.com/owen2345/camaleon-cms/tree/2.4.5.12) (2018-12-04)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.11...2.4.5.12)

**Closed issues:**

- Broken Preview Function for Draft Post [\#861](https://github.com/owen2345/camaleon-cms/issues/861)

## [2.4.5.11](https://github.com/owen2345/camaleon-cms/tree/2.4.5.11) (2018-12-04)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/camaleon_cms-2.4.5.11.gem...2.4.5.11)

## [camaleon_cms-2.4.5.11.gem](https://github.com/owen2345/camaleon-cms/tree/camaleon_cms-2.4.5.11.gem) (2018-12-04)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.10...camaleon_cms-2.4.5.11.gem)

**Closed issues:**

- Some errors in apache proxy  [\#844](https://github.com/owen2345/camaleon-cms/issues/844)

**Merged pull requests:**

- image custom field remove button [\#857](https://github.com/owen2345/camaleon-cms/pull/857) ([superchell](https://github.com/superchell))

## [2.4.5.10](https://github.com/owen2345/camaleon-cms/tree/2.4.5.10) (2018-10-26)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.7...2.4.5.10)

**Closed issues:**

- How to override \_data.js [\#855](https://github.com/owen2345/camaleon-cms/issues/855)
- Update the Website [\#848](https://github.com/owen2345/camaleon-cms/issues/848)
- How can I add new language ? [\#846](https://github.com/owen2345/camaleon-cms/issues/846)
- Site is down [\#840](https://github.com/owen2345/camaleon-cms/issues/840)
- Shortcode yield content  [\#838](https://github.com/owen2345/camaleon-cms/issues/838)
- Problems loading the Documentation [\#837](https://github.com/owen2345/camaleon-cms/issues/837)
- install problem [\#833](https://github.com/owen2345/camaleon-cms/issues/833)
- Route problem [\#827](https://github.com/owen2345/camaleon-cms/issues/827)
- Multilanguage and varchar field length issue [\#820](https://github.com/owen2345/camaleon-cms/issues/820)
- Test fix prevents testing plugins [\#817](https://github.com/owen2345/camaleon-cms/issues/817)
- Support for old Ruby/Rails versions [\#813](https://github.com/owen2345/camaleon-cms/issues/813)
- Images are not being created in different versions [\#808](https://github.com/owen2345/camaleon-cms/issues/808)
- Uploading image doesn't auto orient [\#786](https://github.com/owen2345/camaleon-cms/issues/786)
- post order problem [\#783](https://github.com/owen2345/camaleon-cms/issues/783)
- Cant create theme without sudo [\#771](https://github.com/owen2345/camaleon-cms/issues/771)
- Sprockets::FileNotFound in CamaleonCms::AdminController\#dashboard [\#763](https://github.com/owen2345/camaleon-cms/issues/763)
- AWS Media doesn't scale [\#757](https://github.com/owen2345/camaleon-cms/issues/757)
- Unable to add attachments to custom content type [\#753](https://github.com/owen2345/camaleon-cms/issues/753)
- Contact form throws error on submission [\#729](https://github.com/owen2345/camaleon-cms/issues/729)
- We're sorry, but something went wrong. If you are the application owner check the logs for more information. [\#728](https://github.com/owen2345/camaleon-cms/issues/728)
- Hi Owen [\#727](https://github.com/owen2345/camaleon-cms/issues/727)
- How to implement Paper Trials in Camaleon CMS? [\#725](https://github.com/owen2345/camaleon-cms/issues/725)
- Cannot add custom fields to custom user [\#719](https://github.com/owen2345/camaleon-cms/issues/719)
- Copy from Word into Rich editor? [\#717](https://github.com/owen2345/camaleon-cms/issues/717)
- Default user\_model? [\#715](https://github.com/owen2345/camaleon-cms/issues/715)
- Media gallery uses different path than actual path [\#714](https://github.com/owen2345/camaleon-cms/issues/714)
- Serve camaleon assets from cloudfront? [\#709](https://github.com/owen2345/camaleon-cms/issues/709)
- NoMethodError in CamaleonCms::Admin::InstallersController\#save [\#702](https://github.com/owen2345/camaleon-cms/issues/702)
- Redirect loop with existin devise model [\#699](https://github.com/owen2345/camaleon-cms/issues/699)
- Tags created with tag form do not appear [\#695](https://github.com/owen2345/camaleon-cms/issues/695)
- Tags for multiple post types [\#694](https://github.com/owen2345/camaleon-cms/issues/694)
- NoMethodError in CamaleonCms::Admin\#dashboard [\#687](https://github.com/owen2345/camaleon-cms/issues/687)
- Comment's submit flash messages doesn't shows [\#686](https://github.com/owen2345/camaleon-cms/issues/686)
- Error action save\_comment [\#685](https://github.com/owen2345/camaleon-cms/issues/685)
- NoMethodError in CamaleonCms::Admin::SessionsController\#login\_post [\#684](https://github.com/owen2345/camaleon-cms/issues/684)
- Authoring Posts plugin shows all users instead of current\_site.users [\#681](https://github.com/owen2345/camaleon-cms/issues/681)
- Contact Form Item not translate to chinese [\#606](https://github.com/owen2345/camaleon-cms/issues/606)
- Feature request [\#597](https://github.com/owen2345/camaleon-cms/issues/597)
- warning: already initialized constant JSON::\* [\#596](https://github.com/owen2345/camaleon-cms/issues/596)
- Can I migrate existing pages from BrowserCMS to CamaleonCMS? [\#595](https://github.com/owen2345/camaleon-cms/issues/595)
- I18n.backend translations not working [\#593](https://github.com/owen2345/camaleon-cms/issues/593)
- json pagination problem [\#584](https://github.com/owen2345/camaleon-cms/issues/584)
- Asset Undefined And Testing Repo [\#579](https://github.com/owen2345/camaleon-cms/issues/579)
- Unable to install. Command `gem 'camaleon\_cms'` not working. [\#573](https://github.com/owen2345/camaleon-cms/issues/573)
- Request Update Feature [\#572](https://github.com/owen2345/camaleon-cms/issues/572)
- Using Camaleon with existing database and models [\#567](https://github.com/owen2345/camaleon-cms/issues/567)
- Assign a template to a content-group global page [\#561](https://github.com/owen2345/camaleon-cms/issues/561)
- Bootstrap Sass variable and Mixin are also undefined with Camaleon CMS version 2.4 [\#560](https://github.com/owen2345/camaleon-cms/issues/560)
- Assets conflict [\#557](https://github.com/owen2345/camaleon-cms/issues/557)
- How to avoid N+1 queries in CamaleonCms? [\#556](https://github.com/owen2345/camaleon-cms/issues/556)
- Urgently BUG: Camaleon Version 2.1.1 does not upload file to S3 [\#555](https://github.com/owen2345/camaleon-cms/issues/555)
- Multiple Language: Editor field of other language doesn't show container body to input data [\#552](https://github.com/owen2345/camaleon-cms/issues/552)
- Integrate with an existing authentication system [\#545](https://github.com/owen2345/camaleon-cms/issues/545)
- Rspec tests are failing  [\#540](https://github.com/owen2345/camaleon-cms/issues/540)
- Server migration and image url problem [\#538](https://github.com/owen2345/camaleon-cms/issues/538)
- How to add leadpages to Camaleon [\#535](https://github.com/owen2345/camaleon-cms/issues/535)
- Multi Site: How to assign users to specific sites only? [\#525](https://github.com/owen2345/camaleon-cms/issues/525)
- Image uploader caching is not scalable [\#518](https://github.com/owen2345/camaleon-cms/issues/518)
- Creating a folder in image uploader should clear cache [\#517](https://github.com/owen2345/camaleon-cms/issues/517)
- Theme settings missing [\#513](https://github.com/owen2345/camaleon-cms/issues/513)
- Favicon Causes DNS issues.  [\#510](https://github.com/owen2345/camaleon-cms/issues/510)
- Image upload enhancements [\#509](https://github.com/owen2345/camaleon-cms/issues/509)
- Dynamic URLs for pagination [\#505](https://github.com/owen2345/camaleon-cms/issues/505)
- Test suite does not run [\#470](https://github.com/owen2345/camaleon-cms/issues/470)
- Setting Custom Homepage Via Theme Settings in Default Theme Not Working Correctly [\#467](https://github.com/owen2345/camaleon-cms/issues/467)
- How to create mobile app for Camaleon CMS and subdomains [\#462](https://github.com/owen2345/camaleon-cms/issues/462)
- Direction should be :asc or :desc [\#425](https://github.com/owen2345/camaleon-cms/issues/425)
- How to avoid numeric values in tags [\#403](https://github.com/owen2345/camaleon-cms/issues/403)
- NoMethodError in CamaleonCms::Frontend\#index [\#397](https://github.com/owen2345/camaleon-cms/issues/397)
- Is there a blogs json api? [\#393](https://github.com/owen2345/camaleon-cms/issues/393)
- Themes assets not found on production [\#348](https://github.com/owen2345/camaleon-cms/issues/348)
- Hang in Heroku/Dokku push-deploy [\#321](https://github.com/owen2345/camaleon-cms/issues/321)
- Add Custom field [\#319](https://github.com/owen2345/camaleon-cms/issues/319)
- Custom field types extendable by plugins [\#293](https://github.com/owen2345/camaleon-cms/issues/293)
- MIT License [\#292](https://github.com/owen2345/camaleon-cms/issues/292)
- New user role for basic info, theme setting and Contact Response [\#285](https://github.com/owen2345/camaleon-cms/issues/285)
- Specs not running [\#228](https://github.com/owen2345/camaleon-cms/issues/228)
- Pt-BR translation to admin [\#177](https://github.com/owen2345/camaleon-cms/issues/177)
- "Author Name" Confusion in SEO Settings [\#98](https://github.com/owen2345/camaleon-cms/issues/98)

**Merged pull requests:**

- Support Plugin / Theme usage and development [\#852](https://github.com/owen2345/camaleon-cms/pull/852) ([westonganger](https://github.com/westonganger))
- Fix upload to s3 for private files - Updated [\#851](https://github.com/owen2345/camaleon-cms/pull/851) ([westonganger](https://github.com/westonganger))
- Cleanup cruft in test output [\#850](https://github.com/owen2345/camaleon-cms/pull/850) ([westonganger](https://github.com/westonganger))
- Fix UX for Plugins Activate/Deactivate buttons [\#849](https://github.com/owen2345/camaleon-cms/pull/849) ([westonganger](https://github.com/westonganger))
- Update Project [\#847](https://github.com/owen2345/camaleon-cms/pull/847) ([westonganger](https://github.com/westonganger))
- Ability to search for a post by it's slug [\#841](https://github.com/owen2345/camaleon-cms/pull/841) ([tostasqb](https://github.com/tostasqb))
- fix login page logo [\#836](https://github.com/owen2345/camaleon-cms/pull/836) ([superchell](https://github.com/superchell))
- \[WIP\] Fix upload to s3 for private files [\#830](https://github.com/owen2345/camaleon-cms/pull/830) ([max2320](https://github.com/max2320))
- Add Lang Arabic in Admin Panel [\#828](https://github.com/owen2345/camaleon-cms/pull/828) ([Abd-El-Rahman-HSN](https://github.com/Abd-El-Rahman-HSN))
- Change Color MAIN NAVIGATION And Add Lang Arabic [\#826](https://github.com/owen2345/camaleon-cms/pull/826) ([Abd-El-Rahman-HSN](https://github.com/Abd-El-Rahman-HSN))
- added fix\_list\_elements parameter for TinyMCE [\#823](https://github.com/owen2345/camaleon-cms/pull/823) ([superchell](https://github.com/superchell))
- fixes owen2345/camaleon-cms\#820 [\#822](https://github.com/owen2345/camaleon-cms/pull/822) ([christianmeyer](https://github.com/christianmeyer))
- Remove TinyMCE test workaround that breaks plugin tests [\#819](https://github.com/owen2345/camaleon-cms/pull/819) ([brian-kephart](https://github.com/brian-kephart))
- added last opened folder in the media manager [\#818](https://github.com/owen2345/camaleon-cms/pull/818) ([superchell](https://github.com/superchell))
- Added translatable default value [\#816](https://github.com/owen2345/camaleon-cms/pull/816) ([superchell](https://github.com/superchell))
- Create build matrix in Travis CI and clarify supported versions [\#815](https://github.com/owen2345/camaleon-cms/pull/815) ([brian-kephart](https://github.com/brian-kephart))
- Custom fields groups of custom fields for posts belonging to the same category. [\#814](https://github.com/owen2345/camaleon-cms/pull/814) ([superchell](https://github.com/superchell))
- Cache bundle on Travis CI [\#811](https://github.com/owen2345/camaleon-cms/pull/811) ([brian-kephart](https://github.com/brian-kephart))
- Fix typos in README & gemspec [\#810](https://github.com/owen2345/camaleon-cms/pull/810) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.5.7](https://github.com/owen2345/camaleon-cms/tree/2.4.5.7) (2018-05-15)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.1...2.4.5.7)

**Closed issues:**

- image versions are not created [\#805](https://github.com/owen2345/camaleon-cms/issues/805)
- Plugin tests fail [\#799](https://github.com/owen2345/camaleon-cms/issues/799)
- Redirect after subscription [\#798](https://github.com/owen2345/camaleon-cms/issues/798)
- SVG uploads failing [\#787](https://github.com/owen2345/camaleon-cms/issues/787)
- Updating custom fields does not update parent [\#785](https://github.com/owen2345/camaleon-cms/issues/785)
- Image cropper is broken [\#782](https://github.com/owen2345/camaleon-cms/issues/782)
- wildcard ssl using nginx redirects page to localhost instead of main sub-domained site [\#780](https://github.com/owen2345/camaleon-cms/issues/780)
- \[Request\] Use Travis CI [\#778](https://github.com/owen2345/camaleon-cms/issues/778)
- There should be an endpoint for rendering a 404 page [\#772](https://github.com/owen2345/camaleon-cms/issues/772)
- translation missing: en.camaleon\_cms.admin.post\_type.private [\#768](https://github.com/owen2345/camaleon-cms/issues/768)
- Page not found not giving 404 status code [\#767](https://github.com/owen2345/camaleon-cms/issues/767)
- "wrong number of arguments \(given 1, expected 0\)" when using gretel [\#765](https://github.com/owen2345/camaleon-cms/issues/765)
- Create a folder with spaces breaks image path [\#756](https://github.com/owen2345/camaleon-cms/issues/756)
- ActionController::InvalidCrossOriginRequest: Security warning [\#742](https://github.com/owen2345/camaleon-cms/issues/742)
- Feature Request: Wordpress Import [\#34](https://github.com/owen2345/camaleon-cms/issues/34)

**Merged pull requests:**

- Fix plugin generator so plugin tests pass [\#807](https://github.com/owen2345/camaleon-cms/pull/807) ([brian-kephart](https://github.com/brian-kephart))
- fixed creating uploded image versions [\#806](https://github.com/owen2345/camaleon-cms/pull/806) ([superchell](https://github.com/superchell))
- added parent id data attribute in category list [\#804](https://github.com/owen2345/camaleon-cms/pull/804) ([superchell](https://github.com/superchell))
- added id attribute in category list table tag [\#800](https://github.com/owen2345/camaleon-cms/pull/800) ([superchell](https://github.com/superchell))
- added create and update post\_type hooks [\#797](https://github.com/owen2345/camaleon-cms/pull/797) ([superchell](https://github.com/superchell))
- added create category hooks [\#796](https://github.com/owen2345/camaleon-cms/pull/796) ([superchell](https://github.com/superchell))
- added post type edit link on post elements list page [\#795](https://github.com/owen2345/camaleon-cms/pull/795) ([superchell](https://github.com/superchell))
- more fixed russian translates [\#793](https://github.com/owen2345/camaleon-cms/pull/793) ([superchell](https://github.com/superchell))
- fixed russian translates [\#792](https://github.com/owen2345/camaleon-cms/pull/792) ([superchell](https://github.com/superchell))
- updated Fontawesome link [\#791](https://github.com/owen2345/camaleon-cms/pull/791) ([superchell](https://github.com/superchell))
- fix SVG thumbs on AWS [\#789](https://github.com/owen2345/camaleon-cms/pull/789) ([brian-kephart](https://github.com/brian-kephart))
- convert SVGs to JPEG when editing to avoid errors [\#788](https://github.com/owen2345/camaleon-cms/pull/788) ([brian-kephart](https://github.com/brian-kephart))
- Update camaleon\_cms.gemspec [\#784](https://github.com/owen2345/camaleon-cms/pull/784) ([gdurelle](https://github.com/gdurelle))
- Fix 'before\_upload' hook when uploading to local filesystem [\#775](https://github.com/owen2345/camaleon-cms/pull/775) ([brian-kephart](https://github.com/brian-kephart))
- Created endpoint for page not found [\#773](https://github.com/owen2345/camaleon-cms/pull/773) ([jpac-run](https://github.com/jpac-run))
- fix post\_order when no records [\#770](https://github.com/owen2345/camaleon-cms/pull/770) ([cestivan](https://github.com/cestivan))
- 767: Page not found not giving 404 status code [\#769](https://github.com/owen2345/camaleon-cms/pull/769) ([jpac-run](https://github.com/jpac-run))
- calc post order for persisted record only [\#766](https://github.com/owen2345/camaleon-cms/pull/766) ([cestivan](https://github.com/cestivan))
- Skip forgery check on .js files in /assets [\#764](https://github.com/owen2345/camaleon-cms/pull/764) ([brian-kephart](https://github.com/brian-kephart))
- fix post order bug when old posts are deleted [\#761](https://github.com/owen2345/camaleon-cms/pull/761) ([cestivan](https://github.com/cestivan))
- update will\_paginate column distribution [\#759](https://github.com/owen2345/camaleon-cms/pull/759) ([cestivan](https://github.com/cestivan))
- Slugify folder name when creating [\#758](https://github.com/owen2345/camaleon-cms/pull/758) ([tostasqb](https://github.com/tostasqb))
- Let a hook override the ability to see drafts [\#755](https://github.com/owen2345/camaleon-cms/pull/755) ([tostasqb](https://github.com/tostasqb))
- fix typo error [\#751](https://github.com/owen2345/camaleon-cms/pull/751) ([cestivan](https://github.com/cestivan))
- generate random character when slugify empty [\#750](https://github.com/owen2345/camaleon-cms/pull/750) ([cestivan](https://github.com/cestivan))
- fix post tag created without parent\_id bug [\#749](https://github.com/owen2345/camaleon-cms/pull/749) ([cestivan](https://github.com/cestivan))

## [2.4.5.1](https://github.com/owen2345/camaleon-cms/tree/2.4.5.1) (2018-01-09)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5...2.4.5.1)

**Closed issues:**

- 500 internal server error & can\_edit\_file? in Media [\#744](https://github.com/owen2345/camaleon-cms/issues/744)
- Any recommended approach to deploying from dev/staging to production? [\#743](https://github.com/owen2345/camaleon-cms/issues/743)
- A question about camaleon's asset [\#740](https://github.com/owen2345/camaleon-cms/issues/740)
- add new language to common.yml [\#736](https://github.com/owen2345/camaleon-cms/issues/736)
- the path to the media file breaks when the frontend and backend localizations do not match [\#733](https://github.com/owen2345/camaleon-cms/issues/733)
- Demo page crash [\#713](https://github.com/owen2345/camaleon-cms/issues/713)
- Timestamp of NavMenu and NavMenuItem not updated [\#539](https://github.com/owen2345/camaleon-cms/issues/539)
- TinyMCE Templates [\#463](https://github.com/owen2345/camaleon-cms/issues/463)

**Merged pull requests:**

- Replaces deprecated fields, field\_values and field\_groups associations [\#746](https://github.com/owen2345/camaleon-cms/pull/746) ([fmfdias](https://github.com/fmfdias))
-  Re \#740 modify admin-manifest file [\#741](https://github.com/owen2345/camaleon-cms/pull/741) ([lanzhiheng](https://github.com/lanzhiheng))
- added .svg extansion to validation image files method [\#739](https://github.com/owen2345/camaleon-cms/pull/739) ([superchell](https://github.com/superchell))

## [2.4.5](https://github.com/owen2345/camaleon-cms/tree/2.4.5) (2017-11-23)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.6...2.4.5)

**Closed issues:**

- Unable to upload image: Internal Server Error [\#724](https://github.com/owen2345/camaleon-cms/issues/724)
- How to fix mixed content warnings when moving to production [\#722](https://github.com/owen2345/camaleon-cms/issues/722)
- Inactive site with no page selected is inaccessible [\#690](https://github.com/owen2345/camaleon-cms/issues/690)
- Camaleon store sources ? [\#356](https://github.com/owen2345/camaleon-cms/issues/356)

**Merged pull requests:**

- small fixes of Ukrainian language [\#734](https://github.com/owen2345/camaleon-cms/pull/734) ([superchell](https://github.com/superchell))
- Ukrainian localization [\#732](https://github.com/owen2345/camaleon-cms/pull/732) ([superchell](https://github.com/superchell))

## [2.4.4.6](https://github.com/owen2345/camaleon-cms/tree/2.4.4.6) (2017-11-01)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.5...2.4.4.6)

**Closed issues:**

- No such file or directory @ dir\_initialize [\#720](https://github.com/owen2345/camaleon-cms/issues/720)
- Edit link visible when viewing post category while logged out [\#718](https://github.com/owen2345/camaleon-cms/issues/718)
- Visibility plugin bug: Published Date not ok in list view [\#710](https://github.com/owen2345/camaleon-cms/issues/710)
- Disable create new sites? [\#708](https://github.com/owen2345/camaleon-cms/issues/708)
- Dynamic admin URL at system.json ? [\#707](https://github.com/owen2345/camaleon-cms/issues/707)
- Can't see changes when assigning field group to User [\#704](https://github.com/owen2345/camaleon-cms/issues/704)

**Merged pull requests:**

- Fix \#710 Published Date not ok in list view [\#711](https://github.com/owen2345/camaleon-cms/pull/711) ([tostasqb](https://github.com/tostasqb))
- use custom user model name if it present [\#706](https://github.com/owen2345/camaleon-cms/pull/706) ([vikagalkina](https://github.com/vikagalkina))
- Added GIF file types to asset precompilation. [\#703](https://github.com/owen2345/camaleon-cms/pull/703) ([Vaidaz](https://github.com/Vaidaz))

## [2.4.4.5](https://github.com/owen2345/camaleon-cms/tree/2.4.4.5) (2017-10-09)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.3...2.4.4.5)

**Closed issues:**

- mounting? [\#700](https://github.com/owen2345/camaleon-cms/issues/700)
- Migration does not work [\#692](https://github.com/owen2345/camaleon-cms/issues/692)
- Image custom field [\#294](https://github.com/owen2345/camaleon-cms/issues/294)

## [2.4.4.3](https://github.com/owen2345/camaleon-cms/tree/2.4.4.3) (2017-10-02)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.2...2.4.4.3)

## [2.4.4.2](https://github.com/owen2345/camaleon-cms/tree/2.4.4.2) (2017-10-02)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4...2.4.4.2)

**Closed issues:**

- ActiveModel::UnknownAttributeError in CamaleonCms::Admin::InstallersController\#save [\#698](https://github.com/owen2345/camaleon-cms/issues/698)
- Support with Gitter? [\#697](https://github.com/owen2345/camaleon-cms/issues/697)

## [2.4.4](https://github.com/owen2345/camaleon-cms/tree/2.4.4) (2017-09-30)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.12...2.4.4)

**Closed issues:**

- Not working: users\_share\_sites = false [\#691](https://github.com/owen2345/camaleon-cms/issues/691)
- Assets compilation failing working with webpack [\#688](https://github.com/owen2345/camaleon-cms/issues/688)
- Can't access admin panel for inactive site [\#682](https://github.com/owen2345/camaleon-cms/issues/682)
- Application stops working [\#680](https://github.com/owen2345/camaleon-cms/issues/680)
- Validation with contact\_form [\#679](https://github.com/owen2345/camaleon-cms/issues/679)
- Plugin generator creates duplicate routes in Gemfile [\#663](https://github.com/owen2345/camaleon-cms/issues/663)
- undefined method `saved\_change\_to\_attribute?' for \#\<CamaleonCms::Site:0x007ff468a826b8\> [\#651](https://github.com/owen2345/camaleon-cms/issues/651)

**Merged pull requests:**

- bump cancancan version [\#696](https://github.com/owen2345/camaleon-cms/pull/696) ([wuboy0307](https://github.com/wuboy0307))
- Added hooks for media support [\#693](https://github.com/owen2345/camaleon-cms/pull/693) ([tostasqb](https://github.com/tostasqb))
- Allow login to inactive sites [\#683](https://github.com/owen2345/camaleon-cms/pull/683) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.3.12](https://github.com/owen2345/camaleon-cms/tree/2.4.3.12) (2017-08-13)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.11...2.4.3.12)

**Closed issues:**

- Query to find all object with a certain custom field value [\#673](https://github.com/owen2345/camaleon-cms/issues/673)
- Template is missing [\#612](https://github.com/owen2345/camaleon-cms/issues/612)

**Merged pull requests:**

- Remove outdated data in the session [\#678](https://github.com/owen2345/camaleon-cms/pull/678) ([aspirewit](https://github.com/aspirewit))
- Contrib dev [\#677](https://github.com/owen2345/camaleon-cms/pull/677) ([haffla](https://github.com/haffla))
- fix method to delete folders [\#676](https://github.com/owen2345/camaleon-cms/pull/676) ([haffla](https://github.com/haffla))

## [2.4.3.11](https://github.com/owen2345/camaleon-cms/tree/2.4.3.11) (2017-08-01)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.10...2.4.3.11)

**Closed issues:**

- show/hide custom fields based on another custom fields value [\#671](https://github.com/owen2345/camaleon-cms/issues/671)
- Loop on the multiple group custom fields on the FO [\#668](https://github.com/owen2345/camaleon-cms/issues/668)
- Can't create new custom\_field\_group [\#666](https://github.com/owen2345/camaleon-cms/issues/666)
- Changer order back office [\#665](https://github.com/owen2345/camaleon-cms/issues/665)
- Ukrainian Flag Image [\#664](https://github.com/owen2345/camaleon-cms/issues/664)
- Import Script to Camaleon CMS Database [\#659](https://github.com/owen2345/camaleon-cms/issues/659)
- Content group slug on multiple sites [\#655](https://github.com/owen2345/camaleon-cms/issues/655)
- Multiple Files Uploading [\#653](https://github.com/owen2345/camaleon-cms/issues/653)

**Merged pull requests:**

- fix paths in cache methods [\#670](https://github.com/owen2345/camaleon-cms/pull/670) ([brian-kephart](https://github.com/brian-kephart))
- Add option to invalidate Front Cache rather than deleting it [\#669](https://github.com/owen2345/camaleon-cms/pull/669) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.3.10](https://github.com/owen2345/camaleon-cms/tree/2.4.3.10) (2017-07-08)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.7...2.4.3.10)

**Closed issues:**

- incomplete response in production env [\#661](https://github.com/owen2345/camaleon-cms/issues/661)
- \[Question\] Add fields to post category [\#656](https://github.com/owen2345/camaleon-cms/issues/656)
- admin post\_types page fail to load from time to time [\#634](https://github.com/owen2345/camaleon-cms/issues/634)
- Feature Request: Memcached/Redis support [\#609](https://github.com/owen2345/camaleon-cms/issues/609)

**Merged pull requests:**

- Fix custom fields group issue on Rails 5.1.1 [\#667](https://github.com/owen2345/camaleon-cms/pull/667) ([max2320](https://github.com/max2320))
- Use Rails cache store in Front Cache plugin [\#662](https://github.com/owen2345/camaleon-cms/pull/662) ([brian-kephart](https://github.com/brian-kephart))
- Cast parameters to hash to avoid error in rails 5 [\#660](https://github.com/owen2345/camaleon-cms/pull/660) ([sudoaza](https://github.com/sudoaza))
- upload files sequentially [\#658](https://github.com/owen2345/camaleon-cms/pull/658) ([haffla](https://github.com/haffla))
- using content slug instead of id to prevent conflict between multiple sites [\#657](https://github.com/owen2345/camaleon-cms/pull/657) ([phlcastro](https://github.com/phlcastro))
- fix error when using another model for authentication \(ie.: devise\) [\#654](https://github.com/owen2345/camaleon-cms/pull/654) ([phlcastro](https://github.com/phlcastro))
- memory leak in plugin routes [\#652](https://github.com/owen2345/camaleon-cms/pull/652) ([niedfelj](https://github.com/niedfelj))

## [2.4.3.7](https://github.com/owen2345/camaleon-cms/tree/2.4.3.7) (2017-06-09)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3...2.4.3.7)

**Closed issues:**

- Incomplete Documentation for Draper patch for Rails 5 [\#646](https://github.com/owen2345/camaleon-cms/issues/646)
- the\_related\_posts returns duplicate records [\#637](https://github.com/owen2345/camaleon-cms/issues/637)
- Title tags truncated to 65 chars [\#635](https://github.com/owen2345/camaleon-cms/issues/635)
- db:migrate StandardError Directly inheriting from ActiveRecord::Migration [\#625](https://github.com/owen2345/camaleon-cms/issues/625)
- Front Cache problem with Rails 5.1 [\#624](https://github.com/owen2345/camaleon-cms/issues/624)
- SEO fields not translate to other languages [\#621](https://github.com/owen2345/camaleon-cms/issues/621)
- default slug from title.to\_url [\#619](https://github.com/owen2345/camaleon-cms/issues/619)
- remove pluralize for some locales [\#618](https://github.com/owen2345/camaleon-cms/issues/618)
- TinyMCE error after upgrading to 2.4.3.2 [\#617](https://github.com/owen2345/camaleon-cms/issues/617)
- How to display different versions/dimensions of an image  [\#614](https://github.com/owen2345/camaleon-cms/issues/614)
- User Roles Disabled [\#613](https://github.com/owen2345/camaleon-cms/issues/613)
- Frontend routes issue [\#600](https://github.com/owen2345/camaleon-cms/issues/600)
- Customize email template [\#599](https://github.com/owen2345/camaleon-cms/issues/599)
- How to get the contact form to actually send the emails [\#598](https://github.com/owen2345/camaleon-cms/issues/598)
- Can I migrate existing pages from BrowserCMS to CamaleonCMS? [\#594](https://github.com/owen2345/camaleon-cms/issues/594)
- Validation error [\#591](https://github.com/owen2345/camaleon-cms/issues/591)
- how can I override default\_url\_options [\#590](https://github.com/owen2345/camaleon-cms/issues/590)
- Probably typo in posts controller [\#586](https://github.com/owen2345/camaleon-cms/issues/586)
- upload\_file method in rake task [\#585](https://github.com/owen2345/camaleon-cms/issues/585)
- How to filter featured posts from a specific category [\#583](https://github.com/owen2345/camaleon-cms/issues/583)
- real estate website functionality [\#582](https://github.com/owen2345/camaleon-cms/issues/582)
- Missing pagination in admin user list [\#581](https://github.com/owen2345/camaleon-cms/issues/581)
- Display the featured image [\#580](https://github.com/owen2345/camaleon-cms/issues/580)
- How to loop through custom fields content [\#578](https://github.com/owen2345/camaleon-cms/issues/578)
- MiniMagick::Error when cropping [\#577](https://github.com/owen2345/camaleon-cms/issues/577)
- Can a custom post type be child of another custom post ? [\#576](https://github.com/owen2345/camaleon-cms/issues/576)
- Feature request: title tag for User profiles [\#575](https://github.com/owen2345/camaleon-cms/issues/575)
- S3 errors [\#571](https://github.com/owen2345/camaleon-cms/issues/571)
- Is there a function like blogcard or linkcard? [\#570](https://github.com/owen2345/camaleon-cms/issues/570)
- Colorpicker field type throws JS bugs in console and does not work [\#569](https://github.com/owen2345/camaleon-cms/issues/569)
- Warning: already initialized constant Cama::User [\#566](https://github.com/owen2345/camaleon-cms/issues/566)
- Wrong shortcode post search? [\#565](https://github.com/owen2345/camaleon-cms/issues/565)
- Enable ability to programatically tie a custom field to a post type [\#564](https://github.com/owen2345/camaleon-cms/issues/564)
- All users are have the permissions to update into admin user [\#563](https://github.com/owen2345/camaleon-cms/issues/563)
- Programatically enable custom field groups with multiple groups [\#562](https://github.com/owen2345/camaleon-cms/issues/562)
- No route matches {:action=\>"search", :controller=\>"camaleon\_cms/frontend", :label=\>"search", :slug=\>"welcome"} missing required keys: \[:label\] [\#558](https://github.com/owen2345/camaleon-cms/issues/558)

**Merged pull requests:**

- remove deprecated method 'render :text' [\#650](https://github.com/owen2345/camaleon-cms/pull/650) ([brian-kephart](https://github.com/brian-kephart))
- fix I18n.backend translations [\#649](https://github.com/owen2345/camaleon-cms/pull/649) ([wuboy0307](https://github.com/wuboy0307))
- Update application\_decorator.rb [\#648](https://github.com/owen2345/camaleon-cms/pull/648) ([gordienko](https://github.com/gordienko))
- Fixed NoMethodError undefined method 'paginate' for comments [\#644](https://github.com/owen2345/camaleon-cms/pull/644) ([pulkit21](https://github.com/pulkit21))
- add draft\_child to slug validation [\#643](https://github.com/owen2345/camaleon-cms/pull/643) ([haffla](https://github.com/haffla))
- wrap custom fields setter in activerecord transaction [\#642](https://github.com/owen2345/camaleon-cms/pull/642) ([niedfelj](https://github.com/niedfelj))
- fix restoring of drafts [\#641](https://github.com/owen2345/camaleon-cms/pull/641) ([haffla](https://github.com/haffla))
- Update post\_decorator.rb [\#639](https://github.com/owen2345/camaleon-cms/pull/639) ([brian-kephart](https://github.com/brian-kephart))
- Added PNG and JPG file types to asset precompilation. [\#638](https://github.com/owen2345/camaleon-cms/pull/638) ([WMPayne](https://github.com/WMPayne))
- Wording change [\#636](https://github.com/owen2345/camaleon-cms/pull/636) ([aspirewit](https://github.com/aspirewit))
- prevent nav menu item field 'kind' to be the empty string [\#633](https://github.com/owen2345/camaleon-cms/pull/633) ([haffla](https://github.com/haffla))
- Add the updated\_category hook [\#632](https://github.com/owen2345/camaleon-cms/pull/632) ([aspirewit](https://github.com/aspirewit))
- Add missing Chinese translation [\#631](https://github.com/owen2345/camaleon-cms/pull/631) ([aspirewit](https://github.com/aspirewit))
- Sanitize the filename of uploaded file [\#628](https://github.com/owen2345/camaleon-cms/pull/628) ([aspirewit](https://github.com/aspirewit))
- Improve media manager style [\#626](https://github.com/owen2345/camaleon-cms/pull/626) ([aspirewit](https://github.com/aspirewit))
- Improve gem plugin generator [\#623](https://github.com/owen2345/camaleon-cms/pull/623) ([aspirewit](https://github.com/aspirewit))
- Reassign comments after destroy user [\#622](https://github.com/owen2345/camaleon-cms/pull/622) ([aspirewit](https://github.com/aspirewit))
- translate post type title in posts custom field [\#620](https://github.com/owen2345/camaleon-cms/pull/620) ([haffla](https://github.com/haffla))
- delete file only when it exists [\#616](https://github.com/owen2345/camaleon-cms/pull/616) ([yfractal](https://github.com/yfractal))
- fix invalid key causes validate\_file\_format throw exception [\#615](https://github.com/owen2345/camaleon-cms/pull/615) ([yfractal](https://github.com/yfractal))
- Fix frontend routes issues [\#611](https://github.com/owen2345/camaleon-cms/pull/611) ([aspirewit](https://github.com/aspirewit))
- add missing chinese translation [\#610](https://github.com/owen2345/camaleon-cms/pull/610) ([yfractal](https://github.com/yfractal))
- add trash/restore hooks [\#608](https://github.com/owen2345/camaleon-cms/pull/608) ([haffla](https://github.com/haffla))
- To restrict user change role [\#607](https://github.com/owen2345/camaleon-cms/pull/607) ([aspirewit](https://github.com/aspirewit))
- Fix test cases [\#605](https://github.com/owen2345/camaleon-cms/pull/605) ([aspirewit](https://github.com/aspirewit))
- Removed some automatic pluralizes [\#604](https://github.com/owen2345/camaleon-cms/pull/604) ([aspirewit](https://github.com/aspirewit))
- Add missing Chinese translation [\#603](https://github.com/owen2345/camaleon-cms/pull/603) ([aspirewit](https://github.com/aspirewit))
- Allow the host application to override the translation [\#602](https://github.com/owen2345/camaleon-cms/pull/602) ([aspirewit](https://github.com/aspirewit))
- Revised simplified Chinese translation [\#601](https://github.com/owen2345/camaleon-cms/pull/601) ([aspirewit](https://github.com/aspirewit))
- add translation for logo upload [\#589](https://github.com/owen2345/camaleon-cms/pull/589) ([wuboy0307](https://github.com/wuboy0307))
- German translation - complement [\#574](https://github.com/owen2345/camaleon-cms/pull/574) ([haffla](https://github.com/haffla))
- German translation [\#559](https://github.com/owen2345/camaleon-cms/pull/559) ([haffla](https://github.com/haffla))

## [2.4.3](https://github.com/owen2345/camaleon-cms/tree/2.4.3) (2017-01-07)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.2...2.4.3)

**Closed issues:**

- "Constrain proportions" can't be deselected in editor [\#554](https://github.com/owen2345/camaleon-cms/issues/554)
- Error when saving posts [\#553](https://github.com/owen2345/camaleon-cms/issues/553)

## [2.4.2](https://github.com/owen2345/camaleon-cms/tree/2.4.2) (2016-12-21)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.1...2.4.2)

## [2.4.1](https://github.com/owen2345/camaleon-cms/tree/2.4.1) (2016-12-21)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.0...2.4.1)

**Closed issues:**

- Could you please add haml for designing template? [\#551](https://github.com/owen2345/camaleon-cms/issues/551)
- Coffeescript is not defined [\#550](https://github.com/owen2345/camaleon-cms/issues/550)
- Allow Each Page's Meta Tags to be Editable [\#547](https://github.com/owen2345/camaleon-cms/issues/547)

## [2.4.0](https://github.com/owen2345/camaleon-cms/tree/2.4.0) (2016-12-15)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.7...2.4.0)

**Closed issues:**

- NotNullViolation [\#548](https://github.com/owen2345/camaleon-cms/issues/548)

## [2.3.7](https://github.com/owen2345/camaleon-cms/tree/2.3.7) (2016-12-12)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.6...2.3.7)

**Closed issues:**

- Method overwrite warning when precompiling [\#549](https://github.com/owen2345/camaleon-cms/issues/549)
- RSS feed error [\#544](https://github.com/owen2345/camaleon-cms/issues/544)
- 500 Internal Server Error [\#541](https://github.com/owen2345/camaleon-cms/issues/541)
- Problem with setting post dates [\#534](https://github.com/owen2345/camaleon-cms/issues/534)
- Typo [\#533](https://github.com/owen2345/camaleon-cms/issues/533)
- Question about login [\#532](https://github.com/owen2345/camaleon-cms/issues/532)
- S3 upload options [\#531](https://github.com/owen2345/camaleon-cms/issues/531)
- Deprecation warning [\#530](https://github.com/owen2345/camaleon-cms/issues/530)
- parent\_auth\_token [\#529](https://github.com/owen2345/camaleon-cms/issues/529)
- Request: async loading with cama\_draw\_custom\_assets [\#521](https://github.com/owen2345/camaleon-cms/issues/521)
- Edit link visible when viewing post category while logged out [\#520](https://github.com/owen2345/camaleon-cms/issues/520)
- How to route subdomain to its own domain [\#514](https://github.com/owen2345/camaleon-cms/issues/514)
- Separate URLs for admin and public site [\#507](https://github.com/owen2345/camaleon-cms/issues/507)
- List of available plugins [\#497](https://github.com/owen2345/camaleon-cms/issues/497)
- TypeError in CamaleonCms::Admin::SettingsController\#save\_theme [\#496](https://github.com/owen2345/camaleon-cms/issues/496)
- Theme per Site [\#493](https://github.com/owen2345/camaleon-cms/issues/493)
- How can I Override FrontendController [\#492](https://github.com/owen2345/camaleon-cms/issues/492)
- Rails 5 [\#487](https://github.com/owen2345/camaleon-cms/issues/487)
- Rails console not running [\#485](https://github.com/owen2345/camaleon-cms/issues/485)
- Use only Admin portal of Camaleon with Rails 4 application [\#483](https://github.com/owen2345/camaleon-cms/issues/483)
- Assigning Custom Field Group to Users has no effects. [\#477](https://github.com/owen2345/camaleon-cms/issues/477)
- adding gem to my plugin [\#468](https://github.com/owen2345/camaleon-cms/issues/468)
- Creating content group in rails 5 [\#458](https://github.com/owen2345/camaleon-cms/issues/458)
- ActiveModel::ForbiddenAttributesError Rails 5 [\#450](https://github.com/owen2345/camaleon-cms/issues/450)
- Feature Request: External Link should have target. [\#444](https://github.com/owen2345/camaleon-cms/issues/444)
- Unable to upload media files. [\#418](https://github.com/owen2345/camaleon-cms/issues/418)
- Changing theme reverting back footer info [\#309](https://github.com/owen2345/camaleon-cms/issues/309)
- How to enable amazon S3 storage for all subdomains [\#270](https://github.com/owen2345/camaleon-cms/issues/270)

**Merged pull requests:**

- Adds ButterCMS sponsorship [\#542](https://github.com/owen2345/camaleon-cms/pull/542) ([rogerjin12](https://github.com/rogerjin12))
- Add translations in zh-CN [\#537](https://github.com/owen2345/camaleon-cms/pull/537) ([cheenwe](https://github.com/cheenwe))
- Cleanup and improvements in custom fields classes [\#528](https://github.com/owen2345/camaleon-cms/pull/528) ([sabinahofmann](https://github.com/sabinahofmann))
- Cleanup category class [\#527](https://github.com/owen2345/camaleon-cms/pull/527) ([sabinahofmann](https://github.com/sabinahofmann))
- cleanup and improvements in ability class [\#526](https://github.com/owen2345/camaleon-cms/pull/526) ([sabinahofmann](https://github.com/sabinahofmann))
- Revert "code cleanup in models" [\#523](https://github.com/owen2345/camaleon-cms/pull/523) ([owen2345](https://github.com/owen2345))
- code cleanup in models [\#522](https://github.com/owen2345/camaleon-cms/pull/522) ([sabinahofmann](https://github.com/sabinahofmann))
- Treat username case insensitively when logging in [\#516](https://github.com/owen2345/camaleon-cms/pull/516) ([p-decoraid](https://github.com/p-decoraid))
-  Fix user agent check to work in test environment.  [\#515](https://github.com/owen2345/camaleon-cms/pull/515) ([p-decoraid](https://github.com/p-decoraid))
- Reenable expect syntax as it was used in examples [\#512](https://github.com/owen2345/camaleon-cms/pull/512) ([p-decoraid](https://github.com/p-decoraid))
- Fix checkbox custom fields always being checked in admin [\#511](https://github.com/owen2345/camaleon-cms/pull/511) ([p-decoraid](https://github.com/p-decoraid))
- Lowercase user email addresses [\#508](https://github.com/owen2345/camaleon-cms/pull/508) ([p-decoraid](https://github.com/p-decoraid))
- Fix spelling of AWS S3 [\#506](https://github.com/owen2345/camaleon-cms/pull/506) ([p-decoraid](https://github.com/p-decoraid))
- Added Gemfile.lock to gitignore file [\#504](https://github.com/owen2345/camaleon-cms/pull/504) ([mazharoddin](https://github.com/mazharoddin))
- Explicitly include plugin helper dependency into hooks helper [\#503](https://github.com/owen2345/camaleon-cms/pull/503) ([p-decoraid](https://github.com/p-decoraid))
- Fix some spelling errors [\#502](https://github.com/owen2345/camaleon-cms/pull/502) ([p-decoraid](https://github.com/p-decoraid))
- just make models more readable [\#501](https://github.com/owen2345/camaleon-cms/pull/501) ([p-decoraid](https://github.com/p-decoraid))
- Just a gemfile.lock update [\#500](https://github.com/owen2345/camaleon-cms/pull/500) ([p-decoraid](https://github.com/p-decoraid))
- Drop executable bits on files that are not executable [\#495](https://github.com/owen2345/camaleon-cms/pull/495) ([p-decoraid](https://github.com/p-decoraid))
- Use an English string by default [\#494](https://github.com/owen2345/camaleon-cms/pull/494) ([p-decoraid](https://github.com/p-decoraid))

## [2.3.6](https://github.com/owen2345/camaleon-cms/tree/2.3.6) (2016-09-21)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.5...2.3.6)

## [2.3.5](https://github.com/owen2345/camaleon-cms/tree/2.3.5) (2016-09-19)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.4...2.3.5)

**Closed issues:**

- Release a new version [\#489](https://github.com/owen2345/camaleon-cms/issues/489)
- Performance issues [\#461](https://github.com/owen2345/camaleon-cms/issues/461)

## [2.3.4](https://github.com/owen2345/camaleon-cms/tree/2.3.4) (2016-09-14)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.3...2.3.4)

**Closed issues:**

- Rendering is broken when using narrower window widths [\#481](https://github.com/owen2345/camaleon-cms/issues/481)
- undefined local variable or method `doorkeeper\_token'  error with new changes. [\#476](https://github.com/owen2345/camaleon-cms/issues/476)
- undefined local variable or method `cama\_root\_url' with rails 5.0. [\#473](https://github.com/owen2345/camaleon-cms/issues/473)
- undefined method `id' for nil:NilClass while trying to access ecommerce posts as un logged in user. [\#472](https://github.com/owen2345/camaleon-cms/issues/472)
- Checkbox and Checkboxes in Custom Fields not working proerly [\#464](https://github.com/owen2345/camaleon-cms/issues/464)
- 2.1.2.6 tag missing [\#460](https://github.com/owen2345/camaleon-cms/issues/460)
- Change history [\#459](https://github.com/owen2345/camaleon-cms/issues/459)
- Cannot use shortcode [\#432](https://github.com/owen2345/camaleon-cms/issues/432)

**Merged pull requests:**

- email\_late hook, to permit modifying e.g. smtp settings [\#488](https://github.com/owen2345/camaleon-cms/pull/488) ([p-decoraid](https://github.com/p-decoraid))
- Custom fields diagnostics [\#486](https://github.com/owen2345/camaleon-cms/pull/486) ([p-decoraid](https://github.com/p-decoraid))
- french traduction for admin panel [\#484](https://github.com/owen2345/camaleon-cms/pull/484) ([Gloumy](https://github.com/Gloumy))
- Further work on testing [\#482](https://github.com/owen2345/camaleon-cms/pull/482) ([p-decoraid](https://github.com/p-decoraid))
- Take 3 at doorkeeper\_token fix. [\#480](https://github.com/owen2345/camaleon-cms/pull/480) ([p-decoraid](https://github.com/p-decoraid))
- Work in progress to fix the test suite [\#479](https://github.com/owen2345/camaleon-cms/pull/479) ([p-decoraid](https://github.com/p-decoraid))
- Second fix for doorkeeper\_token/rescue nil [\#478](https://github.com/owen2345/camaleon-cms/pull/478) ([p-decoraid](https://github.com/p-decoraid))
- Move conditionals for clarity [\#475](https://github.com/owen2345/camaleon-cms/pull/475) ([p-decoraid](https://github.com/p-decoraid))
- Do not rescue nil in session helper [\#474](https://github.com/owen2345/camaleon-cms/pull/474) ([p-decoraid](https://github.com/p-decoraid))
- Added an option to show file actions in media modals [\#471](https://github.com/owen2345/camaleon-cms/pull/471) ([p-decoraid](https://github.com/p-decoraid))
- Indicate development dependencies on rspec and capybara [\#469](https://github.com/owen2345/camaleon-cms/pull/469) ([p-decoraid](https://github.com/p-decoraid))
- Handle the case of shortcodes not being initialized, as might happen … [\#466](https://github.com/owen2345/camaleon-cms/pull/466) ([p-decoraid](https://github.com/p-decoraid))

## [2.3.3](https://github.com/owen2345/camaleon-cms/tree/2.3.3) (2016-08-16)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.2...2.3.3)

**Closed issues:**

- ActionController::RoutingError - Media routes fail when you use relative\_url\_root [\#437](https://github.com/owen2345/camaleon-cms/issues/437)

## [2.3.2](https://github.com/owen2345/camaleon-cms/tree/2.3.2) (2016-08-16)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.1...2.3.2)

**Closed issues:**

- Languages support for camaleon [\#457](https://github.com/owen2345/camaleon-cms/issues/457)
- How to create/change ecommerce plugin as multi vendor store [\#453](https://github.com/owen2345/camaleon-cms/issues/453)
- rails generate camaleon\_cms:install :error" Rais 5 [\#452](https://github.com/owen2345/camaleon-cms/issues/452)
- How to run specs [\#429](https://github.com/owen2345/camaleon-cms/issues/429)

## [2.3.1](https://github.com/owen2345/camaleon-cms/tree/2.3.1) (2016-08-12)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.2.0...2.3.1)

**Closed issues:**

- ForbiddenAttributesError  in ShippingMethodsController [\#455](https://github.com/owen2345/camaleon-cms/issues/455)
- Custom PaymentMethod Error  [\#454](https://github.com/owen2345/camaleon-cms/issues/454)
- Slim/ Haml support [\#449](https://github.com/owen2345/camaleon-cms/issues/449)
- Where to define current site?  [\#448](https://github.com/owen2345/camaleon-cms/issues/448)
- Adding custom post type and custom field programmatically.  [\#447](https://github.com/owen2345/camaleon-cms/issues/447)
- Forbidden attributes error [\#446](https://github.com/owen2345/camaleon-cms/issues/446)
- Logo doesn't appear after uploaded. [\#445](https://github.com/owen2345/camaleon-cms/issues/445)
- Camaleon doesn't run in both  rails 4.2.7 and with rails 5 ? [\#443](https://github.com/owen2345/camaleon-cms/issues/443)
- Draft posts can not be published [\#442](https://github.com/owen2345/camaleon-cms/issues/442)
- Camaleon App code [\#436](https://github.com/owen2345/camaleon-cms/issues/436)
- Reorder in menu does not work. [\#435](https://github.com/owen2345/camaleon-cms/issues/435)
- Register FAIL [\#433](https://github.com/owen2345/camaleon-cms/issues/433)
- undefined method `\[\]' for nil:NilClass error whith cms 2.2.1 and ecommerce 1.1 version. [\#428](https://github.com/owen2345/camaleon-cms/issues/428)
- install with rails 5.0 [\#424](https://github.com/owen2345/camaleon-cms/issues/424)
- redirect on creation of a second site [\#423](https://github.com/owen2345/camaleon-cms/issues/423)
- Not administrators users editing profile [\#417](https://github.com/owen2345/camaleon-cms/issues/417)
- Image in template email [\#415](https://github.com/owen2345/camaleon-cms/issues/415)
- What cased this problem ? How to solve this ? [\#413](https://github.com/owen2345/camaleon-cms/issues/413)
- How to override plugin views [\#405](https://github.com/owen2345/camaleon-cms/issues/405)
- uninitialized constant CamaleonCms::Admin::AdminController Error if I use cloudfront URL & while trying to delete Images [\#402](https://github.com/owen2345/camaleon-cms/issues/402)

**Merged pull requests:**

- select content helper [\#441](https://github.com/owen2345/camaleon-cms/pull/441) ([Uysim](https://github.com/Uysim))
- Bugfix set\_field\_values [\#431](https://github.com/owen2345/camaleon-cms/pull/431) ([gcrofils](https://github.com/gcrofils))
- Master [\#430](https://github.com/owen2345/camaleon-cms/pull/430) ([gcrofils](https://github.com/gcrofils))
- Fix relative link to RoR site on sample homepage [\#427](https://github.com/owen2345/camaleon-cms/pull/427) ([alexbrinkman](https://github.com/alexbrinkman))
- Fix typos in admin walkthrough [\#426](https://github.com/owen2345/camaleon-cms/pull/426) ([alexbrinkman](https://github.com/alexbrinkman))
- Enable matching paths as regexes. [\#422](https://github.com/owen2345/camaleon-cms/pull/422) ([stahor](https://github.com/stahor))
- Added fix to ability iteration [\#421](https://github.com/owen2345/camaleon-cms/pull/421) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Frontcache plugin [\#420](https://github.com/owen2345/camaleon-cms/pull/420) ([stahor](https://github.com/stahor))
- Fixed update post button in draft and translations for Pt-BR [\#419](https://github.com/owen2345/camaleon-cms/pull/419) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Fixed update password by normal user [\#416](https://github.com/owen2345/camaleon-cms/pull/416) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Fixed logo image in email template [\#414](https://github.com/owen2345/camaleon-cms/pull/414) ([RafaelTCostella](https://github.com/RafaelTCostella))
- add Português \(Portugal\) [\#411](https://github.com/owen2345/camaleon-cms/pull/411) ([filiperocha](https://github.com/filiperocha))
- stacksmith: Add Dockerfile [\#409](https://github.com/owen2345/camaleon-cms/pull/409) ([stacksmith-bot](https://github.com/stacksmith-bot))
- Update ita translations [\#408](https://github.com/owen2345/camaleon-cms/pull/408) ([ramensoup](https://github.com/ramensoup))
- Permit to change post author [\#372](https://github.com/owen2345/camaleon-cms/pull/372) ([gcrofils](https://github.com/gcrofils))

## [2.2.0](https://github.com/owen2345/camaleon-cms/tree/2.2.0) (2016-06-15)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/0.2.0...2.2.0)

**Closed issues:**

- pt-BR problems [\#407](https://github.com/owen2345/camaleon-cms/issues/407)
- How to change title for posts [\#400](https://github.com/owen2345/camaleon-cms/issues/400)
- File upload size limit [\#377](https://github.com/owen2345/camaleon-cms/issues/377)
- Rails Best Practices [\#346](https://github.com/owen2345/camaleon-cms/issues/346)
- Switch to Devise [\#103](https://github.com/owen2345/camaleon-cms/issues/103)
- Tests [\#74](https://github.com/owen2345/camaleon-cms/issues/74)

**Merged pull requests:**

- Added fixes to translations in Pt-BR [\#406](https://github.com/owen2345/camaleon-cms/pull/406) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Corrected comment for theme\_asset\_path [\#401](https://github.com/owen2345/camaleon-cms/pull/401) ([jebingeosil](https://github.com/jebingeosil))
- I fixed some issues that I see. [\#399](https://github.com/owen2345/camaleon-cms/pull/399) ([codem4ster](https://github.com/codem4ster))

## [2.1.2.1](https://github.com/owen2345/camaleon-cms/tree/2.1.2.1) (2016-05-20)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.2.0...2.1.2.1)

**Closed issues:**

- How to ensure only specified plugins and themse are available for subdomains [\#398](https://github.com/owen2345/camaleon-cms/issues/398)
- Adding translation by admin? [\#395](https://github.com/owen2345/camaleon-cms/issues/395)
- Please Deploy to ruby gem frequently [\#335](https://github.com/owen2345/camaleon-cms/issues/335)
- Unable to use cloudfront  [\#280](https://github.com/owen2345/camaleon-cms/issues/280)
- Theme views aren't added to the view path [\#278](https://github.com/owen2345/camaleon-cms/issues/278)

**Merged pull requests:**

- Update custom\_fields\_read.rb [\#396](https://github.com/owen2345/camaleon-cms/pull/396) ([stahor](https://github.com/stahor))

## [2.1.2.0](https://github.com/owen2345/camaleon-cms/tree/2.1.2.0) (2016-04-29)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/v2.1.1.3...2.1.2.0)

**Closed issues:**

- Custom fields api link broken - https://camaleon.website/custom-fields-api [\#394](https://github.com/owen2345/camaleon-cms/issues/394)
- Not a issue but.. Looking for documentation and camaleon website is down [\#391](https://github.com/owen2345/camaleon-cms/issues/391)
- Cannot use asset in localhost [\#390](https://github.com/owen2345/camaleon-cms/issues/390)
- We would like to suggest that external menu items also have visibility settings [\#389](https://github.com/owen2345/camaleon-cms/issues/389)
- I would like to suggest changing the route name for the back end. [\#388](https://github.com/owen2345/camaleon-cms/issues/388)
- Custom theme for admin interface? [\#387](https://github.com/owen2345/camaleon-cms/issues/387)
- Allow site admin to suspend a subdomain [\#386](https://github.com/owen2345/camaleon-cms/issues/386)
- Media folders can not be deleted with local storage [\#385](https://github.com/owen2345/camaleon-cms/issues/385)
- Sub menues? [\#384](https://github.com/owen2345/camaleon-cms/issues/384)
- Authorization issue [\#383](https://github.com/owen2345/camaleon-cms/issues/383)
- Basic install is generating a permission denied error [\#382](https://github.com/owen2345/camaleon-cms/issues/382)
- Compatibility with rails-composer [\#381](https://github.com/owen2345/camaleon-cms/issues/381)
- change search engine [\#380](https://github.com/owen2345/camaleon-cms/issues/380)
- Typo in CamaleonCms::CustomFieldsRead \(post -\> Post\) ? [\#376](https://github.com/owen2345/camaleon-cms/issues/376)
- How to rename post type menu [\#375](https://github.com/owen2345/camaleon-cms/issues/375)
- Paginate Not Working when custom routes [\#374](https://github.com/owen2345/camaleon-cms/issues/374)
- An unhandled lowlevel error occurred while uploading a photo for a user profile. [\#373](https://github.com/owen2345/camaleon-cms/issues/373)
- Undefined local variable or method `admin\_plugins\_contact\_form\_admin\_forms\_path` [\#370](https://github.com/owen2345/camaleon-cms/issues/370)
- Problem with nav menu generation [\#364](https://github.com/owen2345/camaleon-cms/issues/364)
- Theming tutorial [\#361](https://github.com/owen2345/camaleon-cms/issues/361)
- Sending mail on Heroku [\#360](https://github.com/owen2345/camaleon-cms/issues/360)
- How to close down multiple language support in grain? [\#359](https://github.com/owen2345/camaleon-cms/issues/359)
- Subscribe form  [\#357](https://github.com/owen2345/camaleon-cms/issues/357)
- Docker image [\#355](https://github.com/owen2345/camaleon-cms/issues/355)
- How to let users create subdomains using omniauth [\#354](https://github.com/owen2345/camaleon-cms/issues/354)
- Multiple Custom Field with same value [\#353](https://github.com/owen2345/camaleon-cms/issues/353)
- Camaleon documentation broken [\#342](https://github.com/owen2345/camaleon-cms/issues/342)
- undefined method `get\_taxonomy' error  [\#341](https://github.com/owen2345/camaleon-cms/issues/341)
- Custom Fields [\#329](https://github.com/owen2345/camaleon-cms/issues/329)
- Feature: Role management limited to site [\#325](https://github.com/owen2345/camaleon-cms/issues/325)
- "Slug can't be blank" when creating page [\#323](https://github.com/owen2345/camaleon-cms/issues/323)
- Commit "changed datetimepickerr" breaks creating posts. ref =\>55dfe78906c59df3cb873a8e684f14cfef1b9a56 [\#315](https://github.com/owen2345/camaleon-cms/issues/315)
- nav-menu custom fields 500 error [\#307](https://github.com/owen2345/camaleon-cms/issues/307)
- Dutch Flag Image [\#302](https://github.com/owen2345/camaleon-cms/issues/302)
- Allow users to use cloudfront for AWS S3 bucket [\#291](https://github.com/owen2345/camaleon-cms/issues/291)
- Multiple Domain Needed [\#290](https://github.com/owen2345/camaleon-cms/issues/290)
- Shortcode don't have post's content [\#277](https://github.com/owen2345/camaleon-cms/issues/277)
- Tags on posts? [\#268](https://github.com/owen2345/camaleon-cms/issues/268)
- smtp email settings and notifications [\#265](https://github.com/owen2345/camaleon-cms/issues/265)
- How skip User model? [\#252](https://github.com/owen2345/camaleon-cms/issues/252)
- Reintroduced: Admin section breaks if changing slug of main site [\#249](https://github.com/owen2345/camaleon-cms/issues/249)
- Bug and weird behaivor of the create/update/recover/publish button on post edit/creation section [\#239](https://github.com/owen2345/camaleon-cms/issues/239)
- Wrong locale in backend translation [\#233](https://github.com/owen2345/camaleon-cms/issues/233)
- Permalink link not support utf-8 character [\#194](https://github.com/owen2345/camaleon-cms/issues/194)
- Build nav menu for plugins [\#160](https://github.com/owen2345/camaleon-cms/issues/160)
- Override custom post types in sitemaps [\#157](https://github.com/owen2345/camaleon-cms/issues/157)
- Default layout [\#153](https://github.com/owen2345/camaleon-cms/issues/153)
- Move system.json configuration into environment variables [\#141](https://github.com/owen2345/camaleon-cms/issues/141)
- Custom Post Types [\#129](https://github.com/owen2345/camaleon-cms/issues/129)
- Integrate Post/Page links into tinymce [\#96](https://github.com/owen2345/camaleon-cms/issues/96)
- Post Type form is confusing [\#95](https://github.com/owen2345/camaleon-cms/issues/95)
- Performance [\#93](https://github.com/owen2345/camaleon-cms/issues/93)
- Using Camaleon alongside existing app [\#89](https://github.com/owen2345/camaleon-cms/issues/89)

## [v2.1.1.3](https://github.com/owen2345/camaleon-cms/tree/v2.1.1.3) (2016-04-03)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.2...v2.1.1.3)

**Closed issues:**

- Tinymce attempts to load plugins and themes [\#365](https://github.com/owen2345/camaleon-cms/issues/365)
- Assets not found after clobbering and precompiling assets [\#363](https://github.com/owen2345/camaleon-cms/issues/363)
- Excessive memory consumption problem [\#343](https://github.com/owen2345/camaleon-cms/issues/343)
- How can I have grid editor [\#340](https://github.com/owen2345/camaleon-cms/issues/340)
- example for create custom\_field\_groups at theme installation [\#337](https://github.com/owen2345/camaleon-cms/issues/337)
- Method\_missing sender [\#336](https://github.com/owen2345/camaleon-cms/issues/336)
- Search error [\#330](https://github.com/owen2345/camaleon-cms/issues/330)
- File format not allowed [\#317](https://github.com/owen2345/camaleon-cms/issues/317)
- Media manager "shadow" items [\#313](https://github.com/owen2345/camaleon-cms/issues/313)
- Media manager: can't delete items [\#312](https://github.com/owen2345/camaleon-cms/issues/312)
- Opening category page gives page not found error [\#311](https://github.com/owen2345/camaleon-cms/issues/311)
- CMS demo is broken  [\#306](https://github.com/owen2345/camaleon-cms/issues/306)
- Order post by drag drop [\#296](https://github.com/owen2345/camaleon-cms/issues/296)
- Custom Routes [\#275](https://github.com/owen2345/camaleon-cms/issues/275)
- Translation doesn't work when setting menues [\#271](https://github.com/owen2345/camaleon-cms/issues/271)
- undefined method `init\_seo'  [\#266](https://github.com/owen2345/camaleon-cms/issues/266)
- Custom permalink structure [\#158](https://github.com/owen2345/camaleon-cms/issues/158)

**Merged pull requests:**

- Allow change email subject from hooks [\#371](https://github.com/owen2345/camaleon-cms/pull/371) ([raulanatol](https://github.com/raulanatol))
- Fix tinymce issues when using precompiled assets [\#368](https://github.com/owen2345/camaleon-cms/pull/368) ([cmckni3](https://github.com/cmckni3))
- Fixes media folder navigation [\#367](https://github.com/owen2345/camaleon-cms/pull/367) ([cmckni3](https://github.com/cmckni3))
- Custom fields bugs [\#362](https://github.com/owen2345/camaleon-cms/pull/362) ([cmckni3](https://github.com/cmckni3))
- Add image caption as a default option [\#358](https://github.com/owen2345/camaleon-cms/pull/358) ([gcrofils](https://github.com/gcrofils))
- Fixes sidebar in media search [\#352](https://github.com/owen2345/camaleon-cms/pull/352) ([cmckni3](https://github.com/cmckni3))
- Change searches to be case insensitive [\#351](https://github.com/owen2345/camaleon-cms/pull/351) ([cmckni3](https://github.com/cmckni3))
- Add task to generate thumbnails [\#350](https://github.com/owen2345/camaleon-cms/pull/350) ([cmckni3](https://github.com/cmckni3))
- Add media search [\#349](https://github.com/owen2345/camaleon-cms/pull/349) ([cmckni3](https://github.com/cmckni3))
- Update \_media\_manager.js.coffee [\#347](https://github.com/owen2345/camaleon-cms/pull/347) ([raulanatol](https://github.com/raulanatol))
- Verify if the key on get\_meta is a Symbol before compare [\#339](https://github.com/owen2345/camaleon-cms/pull/339) ([raulanatol](https://github.com/raulanatol))
- moment locale error with locale = en [\#338](https://github.com/owen2345/camaleon-cms/pull/338) ([raulanatol](https://github.com/raulanatol))
- Added hook to customize custom fields render. [\#334](https://github.com/owen2345/camaleon-cms/pull/334) ([raulanatol](https://github.com/raulanatol))
- Temporal log removed [\#333](https://github.com/owen2345/camaleon-cms/pull/333) ([raulanatol](https://github.com/raulanatol))
- Include created\_at order by default [\#332](https://github.com/owen2345/camaleon-cms/pull/332) ([raulanatol](https://github.com/raulanatol))
- per\_page do not use the value of the hook [\#331](https://github.com/owen2345/camaleon-cms/pull/331) ([raulanatol](https://github.com/raulanatol))
- Cleaning useless code [\#326](https://github.com/owen2345/camaleon-cms/pull/326) ([gcrofils](https://github.com/gcrofils))
- Prepare reset password to api methods [\#324](https://github.com/owen2345/camaleon-cms/pull/324) ([raulanatol](https://github.com/raulanatol))
- Contact from email [\#322](https://github.com/owen2345/camaleon-cms/pull/322) ([raulanatol](https://github.com/raulanatol))
- optimized get\_meta when using eager\_load [\#320](https://github.com/owen2345/camaleon-cms/pull/320) ([gcrofils](https://github.com/gcrofils))
- added item\_container\_attrs when drawing menus [\#318](https://github.com/owen2345/camaleon-cms/pull/318) ([gcrofils](https://github.com/gcrofils))
- Email helper error [\#316](https://github.com/owen2345/camaleon-cms/pull/316) ([raulanatol](https://github.com/raulanatol))
- Recovery password using template .html.erb [\#314](https://github.com/owen2345/camaleon-cms/pull/314) ([raulanatol](https://github.com/raulanatol))
- Added russian language YAML file for admin panel [\#310](https://github.com/owen2345/camaleon-cms/pull/310) ([SuperMasterBlasterLaser](https://github.com/SuperMasterBlasterLaser))
- fixes call to partial custom\_fields/render [\#308](https://github.com/owen2345/camaleon-cms/pull/308) ([CBlaize](https://github.com/CBlaize))
- added dutch translation to js.yml [\#304](https://github.com/owen2345/camaleon-cms/pull/304) ([TimVNL](https://github.com/TimVNL))
- Dutch translation update [\#301](https://github.com/owen2345/camaleon-cms/pull/301) ([TimVNL](https://github.com/TimVNL))
- better dutch plugin translation [\#300](https://github.com/owen2345/camaleon-cms/pull/300) ([TimVNL](https://github.com/TimVNL))
- better dutch translation [\#299](https://github.com/owen2345/camaleon-cms/pull/299) ([TimVNL](https://github.com/TimVNL))
- added complete dutch plugin translation [\#298](https://github.com/owen2345/camaleon-cms/pull/298) ([TimVNL](https://github.com/TimVNL))
- added complete dutch locale [\#297](https://github.com/owen2345/camaleon-cms/pull/297) ([TimVNL](https://github.com/TimVNL))

## [2.1.2](https://github.com/owen2345/camaleon-cms/tree/2.1.2) (2016-01-17)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.1...2.1.2)

**Closed issues:**

- Editor and Contributor user roles are cleared when adding a new Post Type [\#289](https://github.com/owen2345/camaleon-cms/issues/289)
- Internal Server Error while trying to upload image on post [\#287](https://github.com/owen2345/camaleon-cms/issues/287)
- NoMethodError if I try to create a subdomain\(slug\) with starting with capital letter [\#286](https://github.com/owen2345/camaleon-cms/issues/286)
- Can't apply font to custom theme [\#284](https://github.com/owen2345/camaleon-cms/issues/284)
- Allow users to create categories on post creation page [\#283](https://github.com/owen2345/camaleon-cms/issues/283)
- Just FYI, your documentation site is down` [\#282](https://github.com/owen2345/camaleon-cms/issues/282)
- How to let users create subdomains  [\#281](https://github.com/owen2345/camaleon-cms/issues/281)
- undefined method `the\_thumb\_url' error if I click on user created tag [\#279](https://github.com/owen2345/camaleon-cms/issues/279)
- Better to have media in current\_site.slug folder [\#272](https://github.com/owen2345/camaleon-cms/issues/272)
- How to use high\_voltage pages as main site home page [\#267](https://github.com/owen2345/camaleon-cms/issues/267)

## [2.1.1](https://github.com/owen2345/camaleon-cms/tree/2.1.1) (2016-01-08)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/v2.0.0...2.1.1)

**Closed issues:**

- NoMethodError in CamaleonCms::Admin::SessionsController\#login\_post [\#274](https://github.com/owen2345/camaleon-cms/issues/274)
- Captcha image broken on your demo site [\#273](https://github.com/owen2345/camaleon-cms/issues/273)
- Multi languages with Contents Route Format =\> content/:post\_type\_title/:slug in Content Group [\#264](https://github.com/owen2345/camaleon-cms/issues/264)
- asset-theme-url incorrect path [\#263](https://github.com/owen2345/camaleon-cms/issues/263)
- Error trying to insert image on post [\#262](https://github.com/owen2345/camaleon-cms/issues/262)
- Contents menu icon personalize [\#260](https://github.com/owen2345/camaleon-cms/issues/260)
- Can not load plugin assets [\#258](https://github.com/owen2345/camaleon-cms/issues/258)
- None Favicon [\#257](https://github.com/owen2345/camaleon-cms/issues/257)
- How did you group your navbar by category under documentation? [\#256](https://github.com/owen2345/camaleon-cms/issues/256)
- show the default theme? [\#255](https://github.com/owen2345/camaleon-cms/issues/255)
- Newbie Question [\#254](https://github.com/owen2345/camaleon-cms/issues/254)
- Deployment to heroku : BreadcrumbsOnRails detected it won't be overridden.  [\#251](https://github.com/owen2345/camaleon-cms/issues/251)
- Upgrade guide [\#250](https://github.com/owen2345/camaleon-cms/issues/250)
- ActionView::MissingTemplate in CamaleonCms::Admin::Settings\#site [\#248](https://github.com/owen2345/camaleon-cms/issues/248)
- TypeError in FrontendController\#index [\#244](https://github.com/owen2345/camaleon-cms/issues/244)
- TypeError \(no implicit conversion of Time into String\) [\#243](https://github.com/owen2345/camaleon-cms/issues/243)
- Logout on frontend redirects to dashboard [\#242](https://github.com/owen2345/camaleon-cms/issues/242)
- Bug when creating post simple custom field group [\#240](https://github.com/owen2345/camaleon-cms/issues/240)
- no implicit conversion of Time into String [\#237](https://github.com/owen2345/camaleon-cms/issues/237)
- Could not find "apps" in any of your source paths [\#236](https://github.com/owen2345/camaleon-cms/issues/236)
- loading of S3 assets in admin media index page takes too long [\#235](https://github.com/owen2345/camaleon-cms/issues/235)
- cannot stop intro popups [\#234](https://github.com/owen2345/camaleon-cms/issues/234)
- NoMethodError in CamaleonCms::Admin::SessionsController\#login\_post [\#232](https://github.com/owen2345/camaleon-cms/issues/232)
- theme generator not working [\#231](https://github.com/owen2345/camaleon-cms/issues/231)
- Cannot go to General Setting page [\#230](https://github.com/owen2345/camaleon-cms/issues/230)
- image custom field [\#229](https://github.com/owen2345/camaleon-cms/issues/229)
- Error when creating a custom field group [\#227](https://github.com/owen2345/camaleon-cms/issues/227)
- Custom Fields: undefined local variable or method `post\_data' [\#224](https://github.com/owen2345/camaleon-cms/issues/224)
- Bug after update v2 ActionView::Template::Error \(undefined local variable or method `root\_url' [\#223](https://github.com/owen2345/camaleon-cms/issues/223)
- Missing template themes camaleon\_cms v2 [\#222](https://github.com/owen2345/camaleon-cms/issues/222)
- Posts feature field [\#220](https://github.com/owen2345/camaleon-cms/issues/220)
- Broken Submit button on "Settings\>General Site\>Filesystem Settings"  [\#218](https://github.com/owen2345/camaleon-cms/issues/218)
- undefined local variable or method `admin\_plugins\_contact\_form\_admin\_forms\_path` for CameleonCms::AdminController [\#216](https://github.com/owen2345/camaleon-cms/issues/216)
- awsS3: missing @fog\_connection.endpoint on moduler branch [\#210](https://github.com/owen2345/camaleon-cms/issues/210)
- undefined method when migrating cameleon1x  [\#209](https://github.com/owen2345/camaleon-cms/issues/209)
- Has Comments? Always true.  [\#208](https://github.com/owen2345/camaleon-cms/issues/208)
- install error [\#207](https://github.com/owen2345/camaleon-cms/issues/207)
- missing template [\#206](https://github.com/owen2345/camaleon-cms/issues/206)
- LoadError "cannot load such file -- faraday" [\#204](https://github.com/owen2345/camaleon-cms/issues/204)
- error after installing AWS-S3 plugin [\#189](https://github.com/owen2345/camaleon-cms/issues/189)
- Undefined local variable or method `params` [\#186](https://github.com/owen2345/camaleon-cms/issues/186)
- Add footer text field [\#185](https://github.com/owen2345/camaleon-cms/issues/185)
- shortcodes.html.erb missing [\#178](https://github.com/owen2345/camaleon-cms/issues/178)
- Document to setup multiple domain with application [\#167](https://github.com/owen2345/camaleon-cms/issues/167)
- Expose camaleon view helpers to ActionController::Base.helpers [\#161](https://github.com/owen2345/camaleon-cms/issues/161)
- Cache problems [\#159](https://github.com/owen2345/camaleon-cms/issues/159)
- AJAX [\#146](https://github.com/owen2345/camaleon-cms/issues/146)
- Admin section breaks if changing slug of main site [\#134](https://github.com/owen2345/camaleon-cms/issues/134)
- Alternative File Manager? [\#107](https://github.com/owen2345/camaleon-cms/issues/107)
- OAuth api  [\#101](https://github.com/owen2345/camaleon-cms/issues/101)
- Images upload on heroku [\#100](https://github.com/owen2345/camaleon-cms/issues/100)

**Merged pull requests:**

- Fix Clean Theme to avoid creating duplicate main\_menu [\#276](https://github.com/owen2345/camaleon-cms/pull/276) ([rubyjedi](https://github.com/rubyjedi))
- cama\_print\_i18n\_value method added to evaluate i18n attributes.  [\#269](https://github.com/owen2345/camaleon-cms/pull/269) ([raulanatol](https://github.com/raulanatol))
- Media style updated [\#261](https://github.com/owen2345/camaleon-cms/pull/261) ([raulanatol](https://github.com/raulanatol))
- Clear api rest files and delete old routes [\#259](https://github.com/owen2345/camaleon-cms/pull/259) ([raulanatol](https://github.com/raulanatol))
- Update \_footer.html.erb [\#253](https://github.com/owen2345/camaleon-cms/pull/253) ([raulanatol](https://github.com/raulanatol))
- Activate user after registration [\#247](https://github.com/owen2345/camaleon-cms/pull/247) ([raulanatol](https://github.com/raulanatol))
- pre\_assets\_content [\#246](https://github.com/owen2345/camaleon-cms/pull/246) ([raulanatol](https://github.com/raulanatol))
- Route error admin\_login\_path [\#245](https://github.com/owen2345/camaleon-cms/pull/245) ([raulanatol](https://github.com/raulanatol))
- parse only current fog dir \#235 [\#241](https://github.com/owen2345/camaleon-cms/pull/241) ([momolog](https://github.com/momolog))
- Adding missing namespaces [\#238](https://github.com/owen2345/camaleon-cms/pull/238) ([mmeyerAlitmetrik](https://github.com/mmeyerAlitmetrik))
- \#134 Change how 'main\_site' is determined, and use the class method i… [\#201](https://github.com/owen2345/camaleon-cms/pull/201) ([marksiemers](https://github.com/marksiemers))
