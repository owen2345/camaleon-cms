# Design — fix-session-locale-and-redirects

## Context

See `proposal.md` — Why. Three independent one-site fixes, one commit each (M15 → M17 → M14).
Constraints:

- #1166 deliberately severed the frontend `session[:cama_current_language]` from admin context
  (the surviving comment in `before_hook_session` records this); the regression is the collateral
  loss of any locale resolution on the login-layout pages, not the severing itself.
- `safe_redirect_url` is the single chokepoint for all three `return_to` consumers
  (login-when-signed-in, post-login cookie in `cama_after_login`, logout), so the casecmp fix
  lands once and covers every call site.
- #1214 made `params[:user_id]` → `params[:id]` the canonical resolution chain
  (`user-target-resolution` capability); the non-scalar hole sits inside that helper, so the fix
  must not reorder the chain.
- `spec/dummy` runs `show_exceptions = :none`, so a 500-class repro must assert the raised
  exception or use the failing status observed through the app's own rescues.

## Goals / Non-Goals

**Goals**

- Pre-auth session pages render in the site's language; `?locale=` works when the site offers it
  and can never 500.
- Same-host `return_to` destinations survive regardless of letter case; cross-host destinations
  still fall back.
- `?user_id[]=` neither crashes member routes nor flips authorization outcomes; it degrades to
  the route target.

**Non-Goals**

- No sibling-site/multisite `return_to` allowlist — cross-host destinations keep falling back;
  that would be its own security change (`camaleon_website` currently runs
  `raise_on_open_redirects = false` awaiting a broader engine review — see the triage note).
- No change to #1214's scalar `user_id` precedence, and no 4xx rejection of non-scalar values —
  degrading to the path target keeps the authorization filter and record lookup agreed on one
  record, which is the capability's invariant.
- No signed-in admin locale changes (`get_admin_language` and the admin layout are untouched —
  the pre-auth pages have no user to read a preference from, which is why the site's languages,
  not a user setting, are the source).

## Decisions

1. **M15 guard = the site's configured languages**, not `I18n.available_locales`: `?locale=` is a
   site-visitor affordance, so a locale the site does not offer should not be selectable even if
   the host app ships translations for it; this also keeps the guard one predicate against data
   already loaded (`get_languages`, symbols, memoized). Unknown values fall back to
   `get_languages.first || I18n.default_locale` — assigning only vetted symbols means
   `I18n::InvalidLocale` is unreachable.
2. **M17 = `casecmp?` validation + canonical-host emission.** Validating alone is not enough:
   Rails 8.1's own guard (`action_on_open_redirect = :raise`, active in `spec/dummy` via
   `load_defaults`) compares hosts case-sensitively in `_url_host_allowed?`, so passing the
   mixed-case URL through `redirect_to` raises `OpenRedirectError` — discovered by the repro
   specs. `safe_redirect_url` therefore rewrites the validated URL's host to `request.host`
   (functionally identical — hosts are case-insensitive) and returns `uri.to_s`, which keeps
   Rails' protection active instead of bypassing it. Rejected: `allow_other_host: true` at the
   three call sites (disables Rails' net exactly where a future regression in our own check
   would need it); downcasing the whole URL (mangles path/query case).
3. **M14 = scalar type-check inside `user_id_param`** (`params[:user_id]` participates only when
   it `is_a?(String)`; query/body params are Strings or containers, so this is exactly
   "scalar"). The helper stays the single place resolution happens; `validate_role`, `set_user`,
   and `updated_ajax` all inherit the fix.
4. **Repro-first specs**, one per finding, in the files named by the proposal. The M14 repro
   pins the admin 500 (`find(Array)` returning an Array that crashes the action) and the
   non-admin self-edit denial; both flip with the fix.

## Triage note — `cama_site_check_existence` (not fixed here)

`camaleon_website` runs `config.action_controller.raise_on_open_redirects = false` with a TODO
naming this method. On current master the method's only cross-host redirect
(`redirect_when_site_missing` → main site URL) already passes `allow_other_host: true` (added
2024-06 in `d335a666`, pre-2.9.2); the inactive/maintenance redirects target the current site's
own posts (same host). The host-app workaround therefore looks stale for the named method, but
flipping the flag back on needs verification across the whole engine (any `redirect_to` of a
`the_url`-derived value can be cross-host on wildcard-subdomain multisite). Spun off as its own
follow-up; no engine change in this PR.

## Post-review addendum

Code review extended the change with three locale-parameter fixes; the decisions:

5. **Non-scalar params never participate, anywhere.** The M14 scalar rule generalizes: a
   non-scalar `?locale=` (admin and frontend) or `?cama_set_language=` is ignored in favor of
   the rest of the resolution chain — not rejected with a 4xx, never a 500. Same rationale as
   M14: degrade to the value the rest of the request already agrees on.
6. **The frontend locale gate fires after theme lookup registration.** Both branches of
   `page_not_found` (the 404 template under the theme layout, a custom `error_404` post via
   `render_post`) need `configure_frontend_lookup_prefixes`; the reorder is safe because
   neither that method nor `theme_init` depends on the locale, and passing requests execute
   the same calls in the same relative order. Rejected: rendering the gate 404 with
   `layout: false` (unstyled, diverges from every other frontend 404).
7. **The rejected locale is replaced before the 404 renders.** `I18n.locale` resets to the
   site's first language so the error page renders in the site's language and
   `default_url_options` does not stamp the rejected locale onto the page's links.

## Risks / Trade-offs

- [A site whose stored `languages_site` meta is malformed] → `get_languages` already rescues to
  the host default; the new code only consumes its output.
- [Callers relying on `?user_id[]=` being denied for self-edits] → that denial was an accident of
  `Array#to_s` never matching; the specified behavior (resolve to the route id) is what #1214's
  chain produces for every other malformed shape.

## Migration Plan

Code-only; no data or schema changes. Deploy normally; rollback = revert the three commits.
