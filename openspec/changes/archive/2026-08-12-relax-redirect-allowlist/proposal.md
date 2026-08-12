## Why

The same-host-only redirect policy is correct for a caller-controlled `return_to`, but it also drops the
*legitimate* off-site redirects a plugin performs after login or registration — an SSO handoff to an
identity provider, or a payment provider's hosted checkout. Those flows set `login_user`'s explicit
`redirect_url` (via the `after_login` hook) or the registration `user_registered` redirect, and the
hardening now sends them to the dashboard/login instead.

Blindly following the hook's value is not an option: a plugin that echoes user input into the redirect
(`r[:redirect_to] = params[:return_url]`) would re-open the exact open redirect from core. The destination
must be *vetted*, not trusted because a hook set it.

## What Changes

- `safe_redirect_url` gains an off-site **allowlist**: an `http`/`https` destination whose host is in the
  `redirect_allowed_hosts` site option (comma-separated) or contributed by the `safe_redirect_hosts` hook
  is followed. Empty by default, so the same-host policy is unchanged until a host is explicitly trusted.
- The server-set redirect arguments gain an explicit **opt-in**: an `after_login`/`user_registered` hook
  may set `r[:allow_external_redirect]` to vouch for a fully-dynamic off-site destination not knowable in
  advance. `login_user` takes a matching `allow_external:` keyword (default false). The opt-in is never
  available to a caller-controlled `return_to`.
- A new `cama_safe_redirect` helper emits a vetted off-site destination with Rails 7+ `allow_other_host`
  (so the framework backstop permits it) while a same-host destination keeps that backstop as a second
  layer. On the Rails 6.1 floor, which has no backstop, no marker is passed.
- The `http`/`https`-only scheme check moves ahead of every host/allowlist/opt-in decision, so no path can
  emit a `javascript:`/`data:` destination — not even to an allowlisted host.

## Notes

- Fail-closed and additive: no option + no hook + no opt-in = today's strict same-host behavior.
  `login_user`'s new `allow_external:` keyword defaults to false, so existing callers are unaffected.

## Out of scope

- Wildcard/subdomain matching in the allowlist (exact host only). Automatic cross-site trust on multisite
  installs remains unsupported — a specific sibling host can be allowlisted, but blanket sibling-site
  support would be a separate change.
