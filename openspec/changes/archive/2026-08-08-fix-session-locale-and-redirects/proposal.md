## Why

The 2026-08 regression audit (`REGRESSION-AUDIT-2026-08-03.md`) confirmed three session-adjacent
medium regressions, batched as PR 3 of the fix plan:

- **M15** — the admin login, register, and forgot-password pages lost localization. #1166 removed
  the locale lines from `SessionsController#before_hook_session` (deliberately dropping the
  frontend `session[:cama_current_language]` from admin context) and #1175 did not restore the
  collateral loss: non-English sites now render those pages in the host's default locale, and
  `?locale=` is ignored.
- **M17** — `SessionHelper#safe_redirect_url` (added by #1168 to close open redirects) compares
  hosts case-sensitively. A `return_to` naming the same host with different casing
  (`HTTP://WWW.Example.COM/…`) is dropped to the fallback path on all three call sites:
  login-when-signed-in, the post-login `return_to` cookie, and logout. Host names are
  case-insensitive (RFC 3986/4343).
- **M14** — the #1214 target-resolution fix made `params[:user_id]` authoritative on member
  routes, but a non-scalar value (`?user_id[]=X`) slips through `user_id_param`:
  `validate_role` mismatches it (wrongly denying self-edits), and for managers
  `set_user`/`updated_ajax`'s `find(Array)` returns an Array that crashes the action with a 500.

## What Changes

- **M15**: `before_hook_session` resolves `I18n.locale` for the login-layout pages from the
  site's configured languages: `?locale=` is honored when the site offers that locale, otherwise
  the site's first language applies. Unknown or unoffered `?locale=` values fall back silently
  (no `I18n::InvalidLocale`). The frontend `session[:cama_current_language]` remains uninvolved —
  #1166's separation stands.
- **M17**: `safe_redirect_url` compares the parsed host to `request.host` case-insensitively
  (`casecmp?`). Relative URLs and same-host absolute URLs (any casing) pass; cross-host values
  are still dropped to the safe fallback. Cross-site `return_to` on multisite remains
  unsupported, now stated in the method's contract (a sibling-site allowlist would be its own
  security change).
- **M14**: `user_id_param` ignores a non-scalar `params[:user_id]`, falling back to the route's
  `:id`. The #1214 scalar-`user_id` precedence is unchanged; `?user_id[]=` requests stop 500ing
  for managers and stop mis-denying self-edits, resolving to the path target instead.

## Capabilities

### New Capabilities

- `admin-login-locale`: locale resolution for the pre-authentication admin session pages
  (login/register/forgot): site languages as the source, `?locale=` availability-guarded,
  frontend session language excluded.
- `session-return-redirects`: the `return_to` redirect policy shared by the three session call
  sites: relative and same-host-any-casing values pass, cross-host and unparsable values fall
  back to the safe default — never an error, never an off-host redirect.

### Modified Capabilities

- `user-target-resolution`: the canonical resolution requirement gains the scalar rule — a
  non-scalar `user_id` parameter does not participate in resolution and the route id is used.

## Impact

- `app/controllers/camaleon_cms/admin/sessions_controller.rb` (`before_hook_session`).
- `app/helpers/camaleon_cms/session_helper.rb` (`safe_redirect_url`).
- `app/controllers/camaleon_cms/admin/users_controller.rb` (`user_id_param`).
- Specs: new `spec/requests/admin/sessions_locale_spec.rb`; extensions to
  `spec/requests/security/open_redirect_session_spec.rb` and
  `spec/requests/admin/users_controller/member_route_target_resolution_spec.rb`.
- No routes, models, JS, or data changes. Behavior deltas: localized session pages return,
  mixed-case same-host `return_to` works again, `?user_id[]=` degrades safely to the route
  target.
